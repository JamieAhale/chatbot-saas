require 'rails_helper'

RSpec.describe ChatService do
  let(:user) { create(:user, queries_remaining: 10, subscription_status: 'active') }
  let(:unique_identifier) { SecureRandom.uuid }
  let(:user_input) { 'What is the capital of France?' }
  let(:service) { described_class.new(user_input, unique_identifier, user) }
  
  describe '#initialize' do
    it 'sets up instance variables correctly' do
      expect(service.instance_variable_get(:@user_input)).to eq(user_input)
      expect(service.instance_variable_get(:@user)).to eq(user)
      expect(service.instance_variable_get(:@unique_identifier)).to eq(unique_identifier)
      expect(service.instance_variable_get(:@assistant_name)).to eq(user.pinecone_assistant_name)
    end
  end
  
  describe '#process_chat' do
    context 'when user input is blank' do
      let(:user_input) { '' }
      
      it 'returns an error' do
        expect(service.process_chat).to eq({ error: 'No user input provided' })
      end
    end
    
    context 'when user cannot make a query' do
      let(:user) { create(:user, queries_remaining: 0, subscription_status: 'active') }
      
      it 'sends a notification email and returns a message' do
        expect(NotificationMailer).to receive(:query_limit_reached).with(user).and_return(double(deliver_later: true))
        
        result = service.process_chat
        expect(result).to eq({ cleaned_response: "We are unable to process your request at this time. Please try again later." })
      end
    end
    
    context 'when user can make a query' do
      let(:conversation) { create(:conversation, user: user, unique_identifier: unique_identifier) }
      let(:pinecone_response) { 
        instance_double(
          Faraday::Response, 
          success?: true, 
          body: {
            choices: [
              {
                message: {
                  content: "Paris is the capital of France.\n\nReferences: Some references here"
                }
              }
            ]
          }.to_json
        )
      }
      
      let(:openai_response) {
        instance_double(
          Faraday::Response,
          body: {
            choices: [
              {
                message: {
                  content: "Question 1?\nQuestion 2?"
                }
              }
            ]
          }.to_json
        )
      }
      
      before do
        allow(Conversation).to receive(:find_or_create_by!).and_return(conversation)
        allow(Faraday).to receive(:post).and_return(pinecone_response, openai_response)
        allow(JSON).to receive(:parse).and_call_original
        allow(service).to receive(:flag_conversation_for_review)
        allow(service).to receive(:check_if_flag_for_review)
        allow(ConversationTitleJob).to receive(:perform_later)
        allow(GenerateSummaryIfIdleJob).to receive(:set).and_return(GenerateSummaryIfIdleJob)
        allow(GenerateSummaryIfIdleJob).to receive(:perform_later)
      end
      
      it 'processes chat and returns a cleaned response with potential queries' do
        # Key expectations
        expect(user).to receive(:decrement_queries!)
        expect(conversation.query_and_responses).to receive(:create).with(
          user_query: user_input,
          assistant_response: "Paris is the capital of France."
        ).and_return(instance_double(QueryAndResponse, persisted?: true))
        
        result = service.process_chat
        expect(result[:cleaned_response]).to eq("Paris is the capital of France.")
        expect(result[:potential_queries]).to eq(["Question 1?", "Question 2?"])
      end
      
      context 'when the response has no citations' do
        let(:pinecone_response) { 
          instance_double(
            Faraday::Response, 
            success?: true, 
            body: {
              choices: [
                {
                  message: {
                    content: "Paris is the capital of France."
                  }
                }
              ]
            }.to_json
          )
        }
        
        it 'flags the conversation for review' do
          expect(service).to receive(:flag_conversation_for_review).with(conversation)
          service.process_chat
        end
      end
      
      context 'when the request to Pinecone fails' do
        let(:pinecone_response) { 
          instance_double(
            Faraday::Response, 
            success?: false, 
            status: 500,
            reason_phrase: 'Internal Server Error'
          )
        }
        
        it 'returns an error' do
          expect(service.process_chat).to eq({ error: "Error: 500 - Internal Server Error" })
        end
      end
    end
  end
  
  describe '#clean_response' do
    it 'removes citations and normalizes punctuation' do
      original_response = "Paris is the capital of France [1, p. 42] . It is known as the City of Light [2, p. 15-17]."
      expected_cleaned = "Paris is the capital of France. It is known as the City of Light."
      
      cleaned, _ = service.send(:clean_response, original_response)
      expect(cleaned).to eq(expected_cleaned)
    end
    
    it 'extracts references when present' do
      original_response = "Paris is the capital of France.\n\nReferences: Book 1, Book 2"
      _, references = service.send(:clean_response, original_response)
      expect(references).to eq("Book 1, Book 2")
    end
  end
  
  describe '#build_messages' do
    let(:conversation) { create(:conversation) }
    
    it 'builds messages from conversation history and current input' do
      # Create more than the allowed number of messages to test limit
      create_list(:query_and_response, 10, conversation: conversation)
      
      messages = service.send(:build_messages, conversation)
      
      # 15 is the max_messages constant in ChatService
      # With the current input, there should be 15 items (7 pairs + current input)
      expect(messages.length).to eq(15)
      expect(messages.last).to eq({ role: 'user', content: user_input })
    end
  end
  
  describe '#flag_conversation_for_review' do
    let(:conversation) { create(:conversation, user: user, flagged_for_review: false) }
    
    before do
      allow(NotificationMailer).to receive(:flagged_for_review).and_return(double(deliver_later: true))
    end
    
    it 'flags the conversation for review' do
      service.send(:flag_conversation_for_review, conversation)
      expect(conversation.flagged_for_review).to be true
    end
    
    it 'sends a notification if email notifications are enabled' do
      user.email_notifications_enabled = true
      expect(NotificationMailer).to receive(:flagged_for_review).with(conversation, user).and_return(double(deliver_later: true))
      service.send(:flag_conversation_for_review, conversation)
    end
    
    it 'does not send a notification if email notifications are disabled' do
      user.email_notifications_enabled = false
      expect(NotificationMailer).not_to receive(:flagged_for_review)
      service.send(:flag_conversation_for_review, conversation)
    end
    
    it 'does nothing if the conversation is already flagged' do
      conversation.flagged_for_review = true
      conversation.save!
      
      expect(conversation).not_to receive(:save!)
      expect(NotificationMailer).not_to receive(:flagged_for_review)
      
      service.send(:flag_conversation_for_review, conversation)
    end
  end
end 
require 'rails_helper'

RSpec.describe Conversation, type: :model do
  describe 'associations' do
    it { should have_many(:query_and_responses).dependent(:destroy) }
    it { should belong_to(:user) }
  end

  describe '.search' do
    let(:user) { create(:user) }
    let!(:conversation1) { create(:conversation, title: 'Meeting discussion', user: user) }
    let!(:conversation2) { create(:conversation, title: 'Project timeline', user: user) }
    let!(:conversation3) { create(:conversation, title: 'Budget planning', user: user) }

    before do
      create(:query_and_response, conversation: conversation1, user_query: 'When is the next team meeting?', assistant_response: 'The next team meeting is on Friday at 2pm.')
      create(:query_and_response, conversation: conversation2, user_query: 'What is the project deadline?', assistant_response: 'The project deadline is December 15th.')
      create(:query_and_response, conversation: conversation3, user_query: 'How much is the marketing budget?', assistant_response: 'The marketing budget is $50,000.')
    end

    it 'returns conversations matching the search term in title' do
      results = Conversation.search('meeting')
      expect(results).to include(conversation1)
      expect(results).not_to include(conversation2)
      expect(results).not_to include(conversation3)
    end

    it 'returns conversations matching the search term in user query' do
      results = Conversation.search('project')
      expect(results).to include(conversation2)
      expect(results).not_to include(conversation1)
      expect(results).not_to include(conversation3)
    end

    it 'returns conversations matching the search term in assistant response' do
      results = Conversation.search('marketing budget')
      expect(results).to include(conversation3)
      expect(results).not_to include(conversation1)
      expect(results).not_to include(conversation2)
    end

    it 'returns distinct conversations when multiple matches exist' do
      create(:query_and_response, conversation: conversation1, user_query: 'What about the project?', assistant_response: 'The project is on track.')
      
      results = Conversation.search('project')
      expect(results.count).to eq(2)
      expect(results).to include(conversation1)
      expect(results).to include(conversation2)
    end

    it 'returns empty collection when no matches exist' do
      results = Conversation.search('nonexistent term')
      expect(results).to be_empty
    end
  end

  describe '#summary_missing?' do
    it 'returns true when summary is blank' do
      conversation = build(:conversation, summary: nil)
      expect(conversation.summary_missing?).to be true
      
      conversation.summary = ''
      expect(conversation.summary_missing?).to be true
    end

    it 'returns false when summary is present' do
      conversation = build(:conversation, summary: 'This is a summary')
      expect(conversation.summary_missing?).to be false
    end
  end

  describe '#generate_summary' do
    let(:conversation) { create(:conversation) }
    let(:openai_api_key) { 'fake-api-key' }
    let(:openai_url) { 'https://api.openai.com/v1/chat/completions' }
    let(:faraday_response) { instance_double(Faraday::Response, body: '{"choices":[{"message":{"content":"This is a summary of the conversation."}}]}') }

    before do
      allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return(openai_api_key)
      allow(Faraday).to receive(:post).and_yield(request_double).and_return(faraday_response)
      allow(JSON).to receive(:parse).and_return({ 'choices' => [{ 'message' => { 'content' => 'This is a summary of the conversation.' } }] })
    end

    let(:request_double) do
      double('request').tap do |req|
        allow(req).to receive(:headers).and_return({})
        allow(req).to receive(:body=)
      end
    end

    it 'generates a summary using OpenAI API and updates the conversation' do
      create(:query_and_response, conversation: conversation, user_query: 'Hello', assistant_response: 'Hi there')
      
      conversation.generate_summary
      
      expect(conversation.summary).to eq('This is a summary of the conversation.')
    end
  end

  describe '#update_last_message_time!' do
    it 'updates last_message_at to the most recent query_and_response created_at' do
      conversation = create(:conversation)
      
      # Create messages with different timestamps
      travel_to(2.days.ago) do
        create(:query_and_response, conversation: conversation)
      end
      
      latest_message = nil
      travel_to(1.hour.ago) do
        latest_message = create(:query_and_response, conversation: conversation)
      end
      
      conversation.update_last_message_time!
      expect(conversation.last_message_at).to be_within(1.second).of(latest_message.created_at)
    end

    it 'uses conversation created_at when no messages exist' do
      conversation = create(:conversation)
      conversation.update_last_message_time!
      expect(conversation.last_message_at).to be_within(1.second).of(conversation.created_at)
    end
  end

  describe '#idle_for?' do
    let(:conversation) { create(:conversation) }

    it 'returns true when conversation has been idle for longer than the specified duration' do
      travel_to(3.hours.ago) do
        conversation.update!(last_message_at: Time.current)
      end
      
      expect(conversation.idle_for?(2.hours)).to be true
    end

    it 'returns false when conversation has been active within the specified duration' do
      travel_to(1.hour.ago) do
        conversation.update!(last_message_at: Time.current)
      end
      
      expect(conversation.idle_for?(2.hours)).to be false
    end

    it 'uses created_at when last_message_at is nil' do
      travel_to(3.hours.ago) do
        conversation.update!(last_message_at: nil, created_at: Time.current)
      end
      
      expect(conversation.idle_for?(2.hours)).to be true
    end
  end
end 
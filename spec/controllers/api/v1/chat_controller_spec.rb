require 'rails_helper'

RSpec.describe Api::V1::ChatController, type: :controller do
  let(:user) { create(:user) }
  
  before do
    sign_in user
  end
  
  describe 'POST #create' do
    let(:chat_service) { instance_double(ChatService) }
    let(:user_input) { 'What is the capital of France?' }
    let(:unique_identifier) { SecureRandom.uuid }
    let(:service_response) { { cleaned_response: 'Paris is the capital of France.', potential_queries: ['Question 1?', 'Question 2?'] } }
    
    before do
      allow(ChatService).to receive(:new).and_return(chat_service)
      allow(chat_service).to receive(:process_chat).and_return(service_response)
    end
    
    it 'processes chat and returns JSON response with results' do
      expect(ChatService).to receive(:new).with(user_input, unique_identifier, user)
      expect(chat_service).to receive(:process_chat)
      
      post :create, params: { 
        chat: {
          user_input: user_input, 
          unique_identifier: unique_identifier,
          admin_account_email: user.email
        }
      }
      
      expect(response.content_type).to include('application/json')
      json_response = JSON.parse(response.body)
      expect(json_response['cleaned_response']).to eq('Paris is the capital of France.')
      expect(json_response['potential_queries']).to eq(['Question 1?', 'Question 2?'])
    end
    
    context 'when the service returns an error' do
      let(:service_response) { { error: 'Error: 500 - Internal Server Error' } }
      
      it 'returns a JSON response with the error' do
        post :create, params: { 
          chat: {
            user_input: user_input, 
            unique_identifier: unique_identifier,
            admin_account_email: user.email
          }
        }
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Error: 500 - Internal Server Error')
      end
    end
  end
  
  describe 'GET #last_messages' do
    let(:conversation) { create(:conversation, user: user, unique_identifier: 'test-identifier') }
    let!(:messages) { create_list(:query_and_response, 3, conversation: conversation) }
    
    it 'returns the last messages for a conversation' do
      get :last_messages, params: { id: 'test-identifier' }
      
      expect(response.content_type).to include('application/json')
      json_response = JSON.parse(response.body)
      expect(json_response['messages'].length).to eq(3)
    end
    
    it 'returns empty array when conversation not found' do
      get :last_messages, params: { id: 'non-existent-id' }
      
      expect(response.content_type).to include('application/json')
      json_response = JSON.parse(response.body)
      expect(json_response['messages']).to eq([])
    end
  end
end
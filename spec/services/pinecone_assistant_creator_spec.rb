require 'rails_helper'

RSpec.describe PineconeAssistantCreator do
  let(:user) { create(:user) }
  let(:service) { described_class.new(user) }
  
  describe '#initialize' do
    it 'sets up instance variables correctly' do
      expect(service.instance_variable_get(:@user)).to eq(user)
      expect(service.instance_variable_get(:@pinecone_api_key)).to eq(ENV['PINECONE_API_KEY'])
      expect(service.instance_variable_get(:@assistant_name)).to eq(user.pinecone_assistant_name)
    end
  end
  
  describe '#create_assistant' do
    let(:faraday_response) { instance_double(Faraday::Response, success?: true, status: 200) }
    let(:faraday_request) { double('Faraday::Request') }
    let(:request_headers) { {} }
    let(:expected_body) { {
      name: user.pinecone_assistant_name,
      instructions: "You are a helpful assistant."
    }.to_json }
    
    before do
      # Setup mock request with hash-like headers access
      allow(faraday_request).to receive(:headers).and_return(request_headers)
      allow(faraday_request).to receive(:body=)
      allow(Faraday).to receive(:post).and_yield(faraday_request).and_return(faraday_response)
    end
    
    it 'makes a request to Pinecone with correct parameters' do
      # Verify the URL is correct
      expect(Faraday).to receive(:post).with('https://api.pinecone.io/assistant/assistants')
      
      # Execute the method
      result = service.create_assistant
      
      # Verify that headers were set correctly
      expect(request_headers['Api-Key']).to eq(ENV['PINECONE_API_KEY'])
      expect(request_headers['Content-Type']).to eq('application/json')
      
      # Verify body was set correctly
      expect(faraday_request).to have_received(:body=).with(expected_body)
      
      # Verify the result is true on success
      expect(result).to be true
    end
    
    context 'when the request fails' do
      let(:faraday_response) { instance_double(Faraday::Response, success?: false, status: 500, reason_phrase: 'Internal Server Error') }
      
      it 'returns false' do
        expect(service.create_assistant).to be false
      end
      
      it 'logs an error message' do
        expect(Rails.logger).to receive(:error).with(/Failed to create Pinecone assistant/)
        service.create_assistant
      end
    end
  end
end 
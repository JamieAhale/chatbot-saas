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
    
    before do
      allow(Faraday).to receive(:post).and_return(faraday_response)
    end
    
    it 'makes a request to Pinecone and returns true on success' do
      expect(Faraday).to receive(:post).with(
        'https://prod-1-data.ke.pinecone.io/assistant',
        kind_of(String),
        {
          'Api-Key' => ENV['PINECONE_API_KEY'],
          'Content-Type' => 'application/json'
        }
      )
      
      expect(service.create_assistant).to be true
    end
    
    context 'when the request fails' do
      let(:faraday_response) { instance_double(Faraday::Response, success?: false, status: 500, reason_phrase: 'Internal Server Error') }
      
      it 'returns false' do
        expect(service.create_assistant).to be false
      end
    end
  end
end 
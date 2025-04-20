require 'rails_helper'

RSpec.describe WebCrawlerService do
  let(:url) { 'https://example.com' }
  let(:user) { create(:user) }
  let(:service) { described_class.new(url, user) }
  
  describe '#crawl' do
    let(:html_content) { '<html><body><h1>Example Website</h1><p>This is a test website.</p></body></html>' }
    let(:cleaned_text) { 'Example Website This is a test website.' }
    let(:text_chunks) { ['Example Website This is a test website.'] }
    let(:pinecone_index_response) { instance_double(Faraday::Response, success?: true, status: 200) }
    
    before do
      allow(HTTParty).to receive(:get).and_return(double(body: html_content))
      allow(service).to receive(:clean_html).and_return(cleaned_text)
      allow(service).to receive(:chunk_text).and_return(text_chunks)
      allow(service).to receive(:index_content_in_pinecone).and_return(pinecone_index_response)
    end
    
    it 'processes website content and indexes it in Pinecone' do
      expect(HTTParty).to receive(:get).with(url)
      expect(service).to receive(:clean_html).with(html_content)
      expect(service).to receive(:chunk_text).with(cleaned_text)
      expect(service).to receive(:index_content_in_pinecone).with(text_chunks, url)
      
      result = service.crawl
      expect(result[:status]).to eq(200)
      expect(result[:message]).to include('Successfully indexed content')
    end
    
    context 'when fetching HTML fails' do
      before do
        allow(HTTParty).to receive(:get).and_raise(StandardError.new('Connection error'))
      end
      
      it 'returns an error message' do
        result = service.crawl
        expect(result[:status]).to eq(500)
        expect(result[:message]).to include('Error crawling website')
      end
    end
    
    context 'when indexing fails' do
      let(:pinecone_index_response) { instance_double(Faraday::Response, success?: false, status: 500, reason_phrase: 'Internal Server Error') }
      
      it 'returns an error message' do
        result = service.crawl
        expect(result[:status]).to eq(500)
        expect(result[:message]).to include('Error indexing content')
      end
    end
  end
  
  describe '#clean_html' do
    it 'removes HTML tags and normalizes whitespace' do
      html = '<html><body><h1>Title</h1><p>Paragraph with <a href="#">link</a>.</p></body></html>'
      expected = 'Title Paragraph with link.'
      
      expect(service.send(:clean_html, html)).to eq(expected)
    end
  end
  
  describe '#chunk_text' do
    it 'splits text into chunks of appropriate size' do
      long_text = "a" * 10000
      chunks = service.send(:chunk_text, long_text)
      
      expect(chunks.length).to be > 1
      expect(chunks.all? { |chunk| chunk.length <= 4000 }).to be true
    end
  end
end 
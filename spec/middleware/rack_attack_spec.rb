require 'rails_helper'

RSpec.describe "Rack::Attack", type: :request do
  before do
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.enabled = true
    
    # Disable Devise confirmation emails during tests
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = false

    # Mock the ChatService to avoid dependency on real user
    allow_any_instance_of(ChatService).to receive(:initialize).and_return(nil)
    allow_any_instance_of(ChatService).to receive(:process_chat).and_return({ cleaned_response: "Test response" })
  end

  after do
    Rack::Attack.enabled = true
    ActionMailer::Base.perform_deliveries = true
  end

  describe "throttling" do
    it "throttles sign in attempts by email" do
      # Simulate 7 login attempts from the same email
      7.times do
        post '/users/sign_in', params: { user: { email: 'test@example.com', password: 'password' } }
      end
      
      # The last request should be throttled
      expect(response.status).to eq(429)
      expect(response.body).to match(/Too many requests/)
    end

    it "throttles sign up attempts by email" do
      # Simulate 7 signup attempts from the same email
      7.times do
        post '/users', params: { 
          user: { 
            email: 'test@example.com', 
            password: 'password',
            password_confirmation: 'password'
          } 
        }
      end
      
      # The last request should be throttled
      expect(response.status).to eq(429)
      expect(response.body).to match(/Too many requests/)
    end

    it "throttles chat endpoint requests by Fingerprint visitor ID" do
      # Verify the limit is set to 20 requests per minute
      throttle = Rack::Attack.throttles['api/v1/chat/fingerprint']
      expect(throttle.limit).to eq(20)
      expect(throttle.period).to eq(60)
      
      # Directly test the throttle rule
      test_visitor_id = "test-visitor-id-123"
      
      # Create a mock request that would be throttled
      mock_request = double("request")
      allow(mock_request).to receive(:path).and_return('/api/v1/chat')
      allow(mock_request).to receive(:post?).and_return(true)
      
      # Mock the body with the visitor_id
      body = StringIO.new({ visitor_id: test_visitor_id }.to_json)
      allow(mock_request).to receive(:body).and_return(body)
      allow(body).to receive(:rewind)
      allow(body).to receive(:read).and_return({ visitor_id: test_visitor_id }.to_json)
      
      # Get the actual throttle rule
      throttle_block = throttle.block
      
      # Call the throttle block with our mock request
      discriminator = throttle_block.call(mock_request)
      
      # Verify it uses the visitor_id as the discriminator
      expect(discriminator).to eq("visitor:#{test_visitor_id}")
      
      # Test with no visitor_id - should return nil, not fall back to IP
      no_id_body = StringIO.new({ message: "Hello" }.to_json)
      allow(mock_request).to receive(:body).and_return(no_id_body)
      allow(no_id_body).to receive(:rewind)
      allow(no_id_body).to receive(:read).and_return({ message: "Hello" }.to_json)
      
      # It should return nil (no fallback to IP)
      no_id_discriminator = throttle_block.call(mock_request)
      expect(no_id_discriminator).to be_nil
    end

    it "tests helper method extract_visitor_id_from_body" do
      # Create a mock request with a visitor_id
      mock_request = double("request")
      body = StringIO.new({ visitor_id: "test-visitor" }.to_json)
      allow(mock_request).to receive(:body).and_return(body)
      allow(body).to receive(:rewind)
      allow(body).to receive(:read).and_return({ visitor_id: "test-visitor" }.to_json)
      
      # Call the helper method
      visitor_id = Rack::Attack.extract_visitor_id_from_body(mock_request)
      
      # Verify it extracts the visitor_id correctly
      expect(visitor_id).to eq("test-visitor")
      
      # Test with no visitor_id
      empty_body = StringIO.new({ message: "Hello" }.to_json)
      allow(mock_request).to receive(:body).and_return(empty_body)
      allow(empty_body).to receive(:rewind)
      allow(empty_body).to receive(:read).and_return({ message: "Hello" }.to_json)
      
      # Call the helper method
      empty_visitor_id = Rack::Attack.extract_visitor_id_from_body(mock_request)
      
      # Verify it returns nil when no visitor_id is present
      expect(empty_visitor_id).to be_nil
    end
    
    it "requires a fingerprint for API requests" do
      # Test the 'require fingerprint' blocklist rule
      blocklist = Rack::Attack.blocklists['require fingerprint']
      blocklist_block = blocklist.block
      
      # Create a mock request without a fingerprint
      mock_request = double("request")
      allow(mock_request).to receive(:path).and_return('/api/v1/chat')
      allow(mock_request).to receive(:post?).and_return(true)
      
      # Mock an empty body
      empty_body = StringIO.new({ message: "Hello" }.to_json)
      allow(mock_request).to receive(:body).and_return(empty_body)
      allow(empty_body).to receive(:rewind)
      allow(empty_body).to receive(:read).and_return({ message: "Hello" }.to_json)
      
      # The request should be blocked (returns true)
      result = blocklist_block.call(mock_request)
      expect(result).to be true
      
      # Now test with a fingerprint - should not be blocked
      body_with_fingerprint = StringIO.new({ visitor_id: "test-visitor", message: "Hello" }.to_json)
      allow(mock_request).to receive(:body).and_return(body_with_fingerprint)
      allow(body_with_fingerprint).to receive(:rewind)
      allow(body_with_fingerprint).to receive(:read).and_return({ visitor_id: "test-visitor", message: "Hello" }.to_json)
      
      # The request should not be blocked (returns false)
      result_with_fingerprint = blocklist_block.call(mock_request)
      expect(result_with_fingerprint).to be false
    end
    
    it "throttles excessive requests by Fingerprint visitor ID" do
      # Verify the limit is set to 30 requests per 5 minutes
      throttle = Rack::Attack.throttles['api/excessive-requests/fingerprint']
      expect(throttle.limit).to eq(30)
      expect(throttle.period).to eq(300) # 5 minutes in seconds
      
      # Test the excessive requests throttle rule
      test_visitor_id = "excessive-visitor-123"
      
      # Create a mock request
      mock_request = double("request")
      allow(mock_request).to receive(:path).and_return('/api/v1/chat')
      
      # Mock the body with the visitor_id
      body = StringIO.new({ visitor_id: test_visitor_id }.to_json)
      allow(mock_request).to receive(:body).and_return(body)
      allow(body).to receive(:rewind)
      allow(body).to receive(:read).and_return({ visitor_id: test_visitor_id }.to_json)
      
      # Get the actual throttle rule
      throttle_block = throttle.block
      
      # Call the throttle block with our mock request
      discriminator = throttle_block.call(mock_request)
      
      # Verify it uses the visitor_id as the discriminator with the visitor: prefix
      expect(discriminator).to eq("visitor:#{test_visitor_id}")
    end
  end
  
  describe "blocklisting" do
    it "blocks visitor IDs that have been blocklisted" do
      # Test that the blocklist rule uses the visitor_id
      test_visitor_id = "blocked-visitor-id-123"
      
      # Create a mock request to test against
      mock_request = double("request")
      allow(mock_request).to receive(:path).and_return('/api/v1/chat')
      
      # Mock the body with the visitor_id
      body = StringIO.new({ visitor_id: test_visitor_id }.to_json)
      allow(mock_request).to receive(:body).and_return(body)
      allow(body).to receive(:rewind)
      allow(body).to receive(:read).and_return({ visitor_id: test_visitor_id }.to_json)
      
      # Get the actual blocklist rule
      blocklist = Rack::Attack.blocklists['block suspicious visitors']
      blocklist_block = blocklist.block
      
      # Test when visitor ID is not blocklisted
      # Should return nil (not blocked)
      result_before = blocklist_block.call(mock_request)
      expect(result_before).to be_nil
      
      # Set up the visitor ID to be blocked
      key = "api/block-candidates/visitor:#{test_visitor_id}_block"
      Rack::Attack.cache.store.write(key, true, expires_in: 24.hours)
      
      # Call the blocklist block with our mock request
      result_after = blocklist_block.call(mock_request)
      
      # Verify the blocklist rule matches our visitor ID
      expect(result_after).to be true
    end

    it "can block a visitor ID programmatically" do
      test_visitor_id = "to-be-blocked-visitor-id"
      
      # Verify the key doesn't exist before blocking
      key = "api/block-candidates/visitor:#{test_visitor_id}_block"
      expect(Rack::Attack.cache.store.read(key)).to be_nil
      
      # Call the block_visitor method 
      Rack::Attack.block_visitor(test_visitor_id, 24.hours)
      
      # Verify the visitor ID is blocked in the cache
      expect(Rack::Attack.cache.store.read(key)).to be true
    end
    
    it "blocks suspicious SQL injection attempts" do
      # Create a mock request with SQL injection pattern
      mock_request = double("request")
      allow(mock_request).to receive(:path).and_return('/api/v1/something')
      allow(mock_request).to receive(:params).and_return({ 
        'query' => "' OR 1=1 --" 
      })
      
      # Test the BadRequestMatcher
      result = Rack::Attack::BadRequestMatcher.match?(mock_request)
      expect(result).to be true
    end
    
    it "blocks path traversal attempts" do
      # Create a mock request with path traversal pattern
      mock_request = double("request")
      allow(mock_request).to receive(:path).and_return('/api/v1/something')
      allow(mock_request).to receive(:params).and_return({ 
        'path' => "../../../etc/passwd" 
      })
      
      # Test the BadRequestMatcher
      result = Rack::Attack::BadRequestMatcher.match?(mock_request)
      expect(result).to be true
    end

    it "provides a custom response for missing fingerprint" do
      # Create a mock request with the 'require fingerprint' match
      mock_request = double("request")
      mock_env = { 'rack.attack.matched' => 'require fingerprint' }
      allow(mock_request).to receive(:env).and_return(mock_env)
      
      # Get the blocklisted responder
      responder = Rack::Attack.blocklisted_responder
      
      # Call the responder with our mock request
      status, headers, body_array = responder.call(mock_request)
      
      # Verify the response
      expect(status).to eq(403)
      expect(headers['Content-Type']).to eq('application/json')
      expect(body_array[0]).to include("JavaScript must be enabled")
    end
  end
  
  describe "notifications" do
    it "subscribes to throttle events to block visitor IDs" do
      # Create a test payload for visitor ID-based throttling
      test_visitor_id = "auto-block-test-visitor"
      visitor_payload = {
        request: double(
          env: {
            "rack.attack.matched" => "api/excessive-requests/fingerprint",
            "rack.attack.match_type" => :throttle,
            "rack.attack.match_discriminator" => "visitor:#{test_visitor_id}"
          }
        )
      }
      
      # Verify block_visitor gets called
      expect(Rack::Attack).to receive(:block_visitor).with(test_visitor_id, 24.hours)
      
      # Trigger the notification
      ActiveSupport::Notifications.instrument("throttle.rack_attack", visitor_payload)
    end
  end
end 
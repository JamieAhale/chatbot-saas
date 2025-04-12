require 'rails_helper'

RSpec.describe "Rack::Attack", type: :request do
  before do
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.enabled = true
    
    # Disable Devise confirmation emails during tests
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = false
  end

  after do
    Rack::Attack.enabled = true
    ActionMailer::Base.perform_deliveries = true
  end

  describe "throttling" do
    it "throttles general requests by IP address" do
      # Simulate 301 requests from the same IP to trigger the general rate limit
      301.times do
        get '/'
      end
      
      # The last request should be throttled
      expect(response.status).to eq(429)
      expect(response.body).to match(/Too many requests/)
    end

    it "throttles sign in attempts by IP address" do
      # Simulate 7 login attempts from the same IP
      7.times do
        post '/users/sign_in', params: { user: { email: 'test@example.com', password: 'password' } }
      end
      
      # The last request should be throttled
      expect(response.status).to eq(429)
      expect(response.body).to match(/Too many requests/)
    end

    it "throttles sign up attempts by IP address" do
      # Simulate 7 signup attempts from the same IP
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
    
    it "throttles chat endpoint requests" do
      # Simulate 31 POST requests to the chat endpoint
      31.times do
        post '/api/v1/chat', params: { message: 'test message' }
      end
      
      # The last request should be throttled
      expect(response.status).to eq(429)
      expect(response.body).to match(/Too many requests/)
    end
    
    it "throttles last_messages endpoint requests" do
      # Simulate 61 GET requests to the last_messages endpoint
      61.times do
        get '/api/v1/chat/test-uuid/last_messages'
      end
      
      # The last request should be throttled
      expect(response.status).to eq(429)
      expect(response.body).to match(/Too many requests/)
    end
  end
  
  describe "blocklisting" do
    it "blocks IPs after too many requests to API endpoints" do
      # First, set up the block for this IP in the cache directly (for testing)
      # Using the write_entry method that accepts key, value, options
      key = "api/block-candidates/ip:127.0.0.1_block"
      Rack::Attack.cache.store.write(key, true, expires_in: 24.hours)
      
      # Now make a request to an API endpoint
      get '/api/v1/chat/test-uuid/last_messages'
      
      # The request should be blocked
      expect(response.status).to eq(403)
      expect(response.body).to match(/Access denied/)
    end
  end
end 
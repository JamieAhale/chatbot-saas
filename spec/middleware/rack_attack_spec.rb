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
  end
end 
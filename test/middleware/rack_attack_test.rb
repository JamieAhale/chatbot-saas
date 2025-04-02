require 'test_helper'

class RackAttackTest < ActionDispatch::IntegrationTest
  setup do
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.enabled = true
  end

  teardown do
    Rack::Attack.enabled = true
  end

  test "throttles sign in attempts by IP address" do
    # Simulate 7 login attempts from the same IP
    7.times do
      post '/users/sign_in', params: { user: { email: 'test@example.com', password: 'password' } }
    end
    
    # The last request should be throttled
    assert_equal 429, response.status
    assert_match /Too many requests/, response.body
  end

  test "throttles sign up attempts by IP address" do
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
    assert_equal 429, response.status
    assert_match /Too many requests/, response.body
  end
end 
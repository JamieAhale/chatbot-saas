RSpec.configure do |config|
  # Add Devise helpers for Request specs
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Devise::Test::IntegrationHelpers, type: :feature
  config.include Warden::Test::Helpers
  
  # Reset Warden after each test
  config.after(:each) do
    Warden.test_reset!
  end
end 
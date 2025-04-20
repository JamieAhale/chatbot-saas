require 'capybara/rspec'
require 'warden/test/helpers'

RSpec.configure do |config|
  config.include Warden::Test::Helpers
  
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, type: :system, js: true) do
    driven_by :selenium_chrome_headless
  end
  
  config.after(:each, type: :system) do
    Warden.test_reset!
  end
end 
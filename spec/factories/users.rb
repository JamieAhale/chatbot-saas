FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'password123' }
    password_confirmation { 'password123' }
    confirmed_at { Time.current }
    plan { ENV.fetch('STRIPE_PRICE_BASIC_ID', 'price_basic') }
    queries_remaining { 100 }
    subscription_status { 'active' }
    email_notifications_enabled { true }
    
    trait :with_conversations do
      after(:create) do |user|
        create_list(:conversation, 3, user: user)
      end
    end
    
    trait :with_empty_queries do
      queries_remaining { 0 }
    end
    
    trait :with_canceled_subscription do
      subscription_status { 'canceled' }
    end
  end
end 
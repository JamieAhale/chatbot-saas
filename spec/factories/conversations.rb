FactoryBot.define do
  factory :conversation do
    title { "Test Conversation" }
    summary { "This is a test conversation summary" }
    unique_identifier { SecureRandom.uuid }
    flagged_for_review { false }
    last_message_at { nil }
    association :user
    
    trait :with_messages do
      after(:create) do |conversation|
        create_list(:query_and_response, 3, conversation: conversation)
      end
    end
    
    trait :flagged do
      flagged_for_review { true }
    end
    
    trait :untitled do
      title { nil }
    end
    
    trait :without_summary do
      summary { nil }
    end
  end
end 
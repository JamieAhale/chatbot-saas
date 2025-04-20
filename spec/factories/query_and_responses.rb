FactoryBot.define do
  factory :query_and_response do
    user_query { "What is the capital of France?" }
    assistant_response { "Paris is the capital of France." }
    association :conversation
  end
end 
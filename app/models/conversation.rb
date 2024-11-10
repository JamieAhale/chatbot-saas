class Conversation < ApplicationRecord
  has_many :query_and_responses, dependent: :destroy
end

class QueryAndResponse < ApplicationRecord
  belongs_to :conversation
  validates :user_query, :assistant_response, presence: true
end

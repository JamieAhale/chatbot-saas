class AddFlaggedForReviewToConversations < ActiveRecord::Migration[7.1]
  def change
    add_column :conversations, :flagged_for_review, :boolean, default: false
  end
end

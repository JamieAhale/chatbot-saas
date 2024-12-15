class AddSummaryAndLastMessageAtToConversations < ActiveRecord::Migration[7.1]
  def change
    add_column :conversations, :summary, :text
    add_column :conversations, :last_message_at, :datetime
  end
end

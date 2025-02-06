class AddUserToConversations < ActiveRecord::Migration[7.1]
  def change
    add_reference :conversations, :user, type: :uuid, null: false, foreign_key: true
  end
end

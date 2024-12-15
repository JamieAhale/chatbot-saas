class AddUniqueIdentifierToConversations < ActiveRecord::Migration[7.1]
  def change
    add_column :conversations, :unique_identifier, :string
  end
end

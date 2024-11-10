class CreateQueryAndResponses < ActiveRecord::Migration[7.1]
  def change
    create_table :query_and_responses do |t|
      t.text :user_query
      t.text :assistant_response
      t.references :conversation, null: false, foreign_key: true

      t.timestamps
    end
  end
end

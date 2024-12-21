class AddSearchIndexesToConversations < ActiveRecord::Migration[7.1]
  def up
    if postgresql?
      execute <<-SQL
        CREATE INDEX index_conversations_on_lower_title 
        ON conversations (LOWER(title));
        
        CREATE INDEX index_query_and_responses_on_lower_user_query 
        ON query_and_responses (LOWER(user_query));
        
        CREATE INDEX index_query_and_responses_on_lower_assistant_response 
        ON query_and_responses (LOWER(assistant_response));
      SQL
    else
      add_index :conversations, :title
      add_index :query_and_responses, :user_query
      add_index :query_and_responses, :assistant_response
    end
  end

  def down
    if postgresql?
      remove_index :conversations, name: 'index_conversations_on_lower_title'
      remove_index :query_and_responses, name: 'index_query_and_responses_on_lower_user_query'
      remove_index :query_and_responses, name: 'index_query_and_responses_on_lower_assistant_response'
    else
      remove_index :conversations, :title
      remove_index :query_and_responses, :user_query
      remove_index :query_and_responses, :assistant_response
    end
  end

  private

  def postgresql?
    ActiveRecord::Base.connection.adapter_name.downcase == 'postgresql'
  end
end

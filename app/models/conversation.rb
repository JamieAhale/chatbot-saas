class Conversation < ApplicationRecord
  has_many :query_and_responses, dependent: :destroy
  
  def self.search(term)
    term = "%#{term.downcase}%"
    if ActiveRecord::Base.connection.adapter_name.downcase == 'postgresql'
      joins(:query_and_responses).where(
        'conversations.title ILIKE :term OR query_and_responses.user_query ILIKE :term OR query_and_responses.assistant_response ILIKE :term',
        term: term
      ).distinct
    else
      joins(:query_and_responses).where(
        'LOWER(conversations.title) LIKE :term OR LOWER(query_and_responses.user_query) LIKE :term OR LOWER(query_and_responses.assistant_response) LIKE :term',
        term: term
      ).distinct
    end
  end

  def summary_missing?
    summary.blank?
  end

  def generate_summary
    openai_api_key = ENV['OPENAI_API_KEY']
    openai_url = "https://api.openai.com/v1/chat/completions"
    messages = query_and_responses.last(100).map do |qr|
      [
        { role: 'user', content: qr.user_query },
        { role: 'assistant', content: qr.assistant_response }
      ]
    end.flatten

    messages.unshift({ role: 'system', content: "You are a carefully and accurately summarize conversations to understand what the user is trying to accomplish. Summarize this conversation in 100 words or less from the perspective of an outsider reading the conversation history." })

    puts "MESSAGES: #{messages.inspect}"
    summary_response = Faraday.post(openai_url) do |req|
      req.headers['Authorization'] = "Bearer #{openai_api_key}"
      req.headers['Content-Type'] = 'application/json'
      req.body = {
        model: 'gpt-4o-mini',
        messages: messages
      }.to_json
    end
    parsed_summary_response = JSON.parse(summary_response.body)
    puts "PARSED SUMMARY RESPONSE: #{parsed_summary_response.inspect}"
    new_summary = parsed_summary_response['choices'][0]['message']['content'].strip
    update!(summary: new_summary)
  end

  # Update the last message timestamp
  def update_last_message_time!
    update!(last_message_at: query_and_responses.maximum(:created_at) || created_at)
  end

  # Check if the conversation has been idle for a given duration
  def idle_for?(duration)
    Time.current - (last_message_at || created_at) >= duration
  end
end

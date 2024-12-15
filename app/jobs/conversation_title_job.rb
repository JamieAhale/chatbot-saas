class ConversationTitleJob < ApplicationJob
  queue_as :default

  def perform(conversation_id, user_input)
    conversation = Conversation.find_by(id: conversation_id)
    openai_api_key = ENV['OPENAI_API_KEY']
    openai_url = "https://api.openai.com/v1/chat/completions"

    title_response = Faraday.post(openai_url) do |req|
      req.headers['Authorization'] = "Bearer #{openai_api_key}"
      req.headers['Content-Type'] = 'application/json'
      req.body = {
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: "You are a helpful assistant that summarizes messages clearly and concisely." },
          { role: 'user', content: "Summarize this message to create a title for the conversation: #{user_input}" }
        ]
      }.to_json
    end

    parsed_title_response = JSON.parse(title_response.body)
    title_content = parsed_title_response['choices'][0]['message']['content'].strip

    conversation.title = title_content
    conversation.save!
  end
end

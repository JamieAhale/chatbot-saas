class CheckIfFlagForReviewJob < ApplicationJob
  queue_as :default

  def perform(conversation_id, user_input, main_response, user)
    conversation = Conversation.find_by(id: conversation_id)
    openai_api_key = ENV['OPENAI_API_KEY']
    openai_url = "https://api.openai.com/v1/chat/completions"
    evaluation_response = Faraday.post(openai_url) do |req|
      req.headers['Authorization'] = "Bearer #{openai_api_key}"
      req.headers['Content-Type'] = 'application/json'
      req.body = {
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: "You are a highly analytical evaluator. Your job is to decide if the response answers the question with useful information. If it does, respond with 'Yes'. If it doesn't, respond with 'No'" },
          { role: 'user', content: "Question: #{user_input}, Response: #{main_response}" }
        ]
      }.to_json
    end

    parsed_evaluation_response = JSON.parse(evaluation_response.body)
    evaluation = parsed_evaluation_response['choices'][0]['message']['content'].strip

    if evaluation == 'No'
      conversation.flagged_for_review = true
      conversation.save!
      NotificationMailer.flagged_for_review(conversation, user).deliver_now if user.email_notifications_enabled
    end
  end
end

class ChatService
  def initialize(user_input, unique_identifier, user)
    @user_input = user_input
    @user = user
    @unique_identifier = unique_identifier
    @pinecone_api_key = ENV['PINECONE_API_KEY']
    @assistant_name = user.pinecone_assistant_name
    @openai_api_key = ENV['OPENAI_API_KEY']
    @openai_url = "https://api.openai.com/v1/chat/completions"
    @pinecone_assistant_url = "https://prod-1-data.ke.pinecone.io/assistant/chat/#{@assistant_name}/chat/completions"
  end

  def process_chat
    return { error: 'No user input provided' } if @user_input.blank?
    if @user.can_make_query?
      @user.decrement_queries!
      conversation = find_or_create_conversation
      messages = build_messages(conversation)

      response = send_request_to_pinecone(messages)
      puts "RESPONSE: #{response.inspect}"
      return { error: "Error: #{response.status} - #{response.reason_phrase}" } unless response.success?

      parsed_response = JSON.parse(response.body)
      assistant_response = parsed_response['choices'][0]['message']['content']
      cleaned_response, citations = clean_response(assistant_response)

      check_if_flag_for_review(conversation, @user_input, cleaned_response, @user)

      puts "CITATIONS: #{citations}"

      if citations.nil?
        flag_conversation_for_review(conversation)
      else
        potential_queries = generate_potential_queries(messages)
        puts "POTENTIAL QUERIES: #{potential_queries}"
      end

      puts "CLEANED RESPONSE: #{cleaned_response}"

      save_conversation(conversation, cleaned_response)

      { cleaned_response: cleaned_response, potential_queries: potential_queries }
    else
      NotificationMailer.query_limit_reached(@user).deliver_later
      { cleaned_response: "We are unable to process your request at this time. Please try again later." }
    end
  end

  private

  def find_or_create_conversation
    # conversation = Conversation.find_or_create_by!(unique_identifier: @unique_identifier)
    conversation = Conversation.find_or_create_by!(unique_identifier: @unique_identifier, user: @user)
    conversation
  end

  def build_messages(conversation)
    messages = conversation.query_and_responses.map do |qr|
      [
        { role: 'user', content: qr.user_query },
        { role: 'assistant', content: qr.assistant_response }
      ]
    end.flatten
    messages << { role: 'user', content: @user_input }
    messages
  end

  def send_request_to_pinecone(messages)
    Faraday.post(@pinecone_assistant_url) do |req|
      req.headers['Api-Key'] = @pinecone_api_key
      req.headers['Content-Type'] = 'application/json'
      req.body = {
        model: 'gpt-4o',
        streaming: false,
        messages: messages
      }.to_json
    end
  end

  def clean_response(assistant_response)
    response_parts = assistant_response.split("References:")
    main_response = response_parts[0].strip
    references = response_parts[1]&.strip

    cleaned_response = main_response
                       .gsub(/\s*\[\d+, pp?\.? ?\d+(-\d+)?(, \d+)*\]/, '')
                       .gsub(/\s+([.,!?])/, '\1')
                       .strip
    [cleaned_response, references]
  end

  def save_conversation(conversation, cleaned_response)
    if conversation.title.blank?
      generate_title(conversation)
    end
    message = conversation.query_and_responses.create(
      user_query: @user_input,
      assistant_response: cleaned_response
    )
    if message.persisted?
      conversation.update_last_message_time!
      GenerateSummaryIfIdleJob.set(wait: 5.minutes).perform_later(conversation.id)
    end
  end

  def generate_potential_queries(messages)
    potential_queries_response = Faraday.post(@openai_url) do |req|
      req.headers['Authorization'] = "Bearer #{@openai_api_key}"
      req.headers['Content-Type'] = 'application/json'
      req.body = {
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: "You are a helpful assistant that suggests potential follow-up questions from the USER'S PERSPECTIVE. Try to keep your responses to 5 words or less. Give responses as 2 plain sentences" },
          { role: 'user', content: "Based on this conversation, suggest 2 potential follow-up questions the user may want to ask. Conversation: #{messages}" }
        ]
      }.to_json
    end
    parsed_potential_queries_response = JSON.parse(potential_queries_response.body)
    potential_queries_content = parsed_potential_queries_response['choices'][0]['message']['content'].strip
    potential_queries_content.split("\n").map(&:strip).reject(&:empty?)
  end

  def generate_title(conversation)
    ConversationTitleJob.perform_later(conversation.id, @user_input)
    # Thread.new do
    #   if conversation.title.blank?
    #     title_response = Faraday.post(@openai_url) do |req|
    #       req.headers['Authorization'] = "Bearer #{@openai_api_key}"
    #       req.headers['Content-Type'] = 'application/json'
    #       req.body = {
    #         model: 'gpt-4o-mini',
    #         messages: [
    #           { role: 'system', content: "You are a helpful assistant that summarizes messages clearly and concisely." },
    #           { role: 'user', content: "Summarize this message to create a title for the conversation: #{@user_input}" }
    #         ]
    #       }.to_json
    #     end
    #     parsed_title_response = JSON.parse(title_response.body)
    #     title = parsed_title_response['choices'][0]['message']['content'].strip
    #     conversation.update!(title: title)
    #   end
    # end
  end

  def flag_conversation_for_review(conversation)
    unless conversation.flagged_for_review
      conversation.flagged_for_review = true
      if conversation.save!
        NotificationMailer.flagged_for_review(conversation, @user).deliver_later if @user.email_notifications_enabled
      end
    end
  end

  def check_if_flag_for_review(conversation, user_input, cleaned_response, user)
    CheckIfFlagForReviewJob.perform_later(conversation.id, user_input, cleaned_response, user)
    # Thread.new do
    #   openai_api_key = ENV['OPENAI_API_KEY']
    #   openai_url = "https://api.openai.com/v1/chat/completions"
    #   evaluation_response = Faraday.post(openai_url) do |req|
    #     req.headers['Authorization'] = "Bearer #{openai_api_key}"
    #     req.headers['Content-Type'] = 'application/json'
    #     req.body = {
    #       model: 'gpt-4o-mini',
    #       messages: [
    #         { role: 'system', content: "You are a highly analytical evaluator. Your job is to decide if the response answers the question with useful information. If it does, answer with 'Yes'. If it doesn't, answer with 'No', especially if it only reccomends directly contacting someone." },
    #         { role: 'user', content: "Question: #{@user_input}, Response: #{cleaned_response}" }
    #       ]
    #     }.to_json
    #   end

    #   parsed_evaluation_response = JSON.parse(evaluation_response.body)
    #   evaluation = parsed_evaluation_response['choices'][0]['message']['content'].strip

    #   puts "EVALUATION: #{evaluation}"
    #   if evaluation == 'No'
    #     flag_conversation_for_review(conversation)
    #   end
    # end
  end
end

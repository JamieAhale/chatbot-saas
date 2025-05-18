# app/controllers/assistants_controller.rb
class AssistantsController < ApplicationController
  require 'faraday'
  require 'json'
  require 'multipart/post'
  require 'httparty'

  before_action :authenticate_user!

  def chat
    if params[:user_input].present?
      api_key = ENV['PINECONE_API_KEY']
      assistant_name = "#{current_user.pinecone_assistant_name}"
      url = "https://prod-1-data.ke.pinecone.io/assistant/chat/#{assistant_name}/chat/completions"

      # Retrieve or create the current conversation
      conversation = if session[:conversation_id]
                       Conversation.find(session[:conversation_id])
                     else
                       new_conversation = Conversation.create
                       session[:conversation_id] = new_conversation.id
                       new_conversation
                     end
  
      user_input = params[:user_input]
  
      # Prepare the conversation history for the API request
      messages = conversation.query_and_responses.map do |qr|
        [
          { role: 'user', content: qr.user_query },
          { role: 'assistant', content: qr.assistant_response }
        ]
      end.flatten
  
      # Append the current user input
      messages << { role: 'user', content: user_input }
  
      # API request to Pinecone Assistant
      response = Faraday.post(url) do |req|
        req.headers['Api-Key'] = api_key
        req.headers['Content-Type'] = 'application/json'
        req.body = {
          model: 'gpt-4o',
          streaming: false,
          messages: messages
        }.to_json
      end

      # puts "response: #{response.inspect}"
  
      if response.success?
        parsed_response = JSON.parse(response.body)
        assistant_response = parsed_response['choices'][0]['message']['content']
        puts "ASSISTANT RESPONSE: #{assistant_response}"

        # Separate the main response from the references
        response_parts = assistant_response.split("References:")
        main_response = response_parts[0].strip
        references = response_parts[1]&.strip

        CheckIfFlagForReviewJob.perform_later(conversation.id, user_input, main_response, current_user)

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
        #         { role: 'user', content: "Question: #{user_input}, Response: #{main_response}" }
        #       ]
        #     }.to_json
        #   end

        #   parsed_evaluation_response = JSON.parse(evaluation_response.body)
        #   evaluation = parsed_evaluation_response['choices'][0]['message']['content'].strip

        #   puts "EVALUATION: #{evaluation}"
        #   if evaluation == 'No'
        #     conversation.flagged_for_review = true
        #     conversation.save!
        #     NotificationMailer.flagged_for_review(conversation, current_user).deliver_later if current_user.email_notifications_enabled
        #   end
        # end

        # Remove inline references and spaces before punctuation
        cleaned_response = main_response
                     .gsub(/\s*\[\d+, pp?\.? ?\d+(-\d+)?(, \d+)*\]/, '')
                     .gsub(/\s+([.,!?])/, '\1')
                     .strip
        puts "CLEANED ASSISTANT RESPONSE: #{cleaned_response}"

        # Assign references to citations if they exist
        citations = references if references.present?
        puts "CITATIONS: #{citations.inspect}"

        if citations.nil?
          conversation.flagged_for_review = true
          if conversation.save!
            NotificationMailer.flagged_for_review(conversation, current_user).deliver_later if current_user.email_notifications_enabled
          end
        else
          openai_api_key = ENV['OPENAI_API_KEY']
          openai_url = "https://api.openai.com/v1/chat/completions"

          potential_queries_response = Faraday.post(openai_url) do |req|
            req.headers['Authorization'] = "Bearer #{openai_api_key}"
            req.headers['Content-Type'] = 'application/json'
            req.body = {
              model: 'gpt-4o-mini',
              messages: [
                { role: 'system', content: "You are a helpful assistant that suggests potential follow-up questions. Try to keep your responses to 5 words or less." },
                { role: 'user', content: "Based on this question and answer, suggest two potential follow-up questions. Question: #{user_input}, Answer: #{cleaned_response}" }
              ]
            }.to_json
          end

          parsed_potential_queries_response = JSON.parse(potential_queries_response.body)
          potential_queries_content = parsed_potential_queries_response['choices'][0]['message']['content'].strip

          potential_queries = potential_queries_content.split("\n").map(&:strip).reject(&:empty?)

          puts "POTENTIAL QUERIES: #{potential_queries.inspect}"
        end

        # Save the query and response
        message = conversation.query_and_responses.create(
          user_query: user_input,
          assistant_response: cleaned_response
        )

        if message.persisted?
          puts "MESSAGE PERSISTED"
          conversation.update_last_message_time!
          GenerateSummaryIfIdleJob.set(wait: 5.minutes).perform_later(conversation.id)
          puts "GENERATE SUMMARY JOB SET"
        end

        if conversation.title.blank?
          ConversationTitleJob.perform_later(conversation.id, user_input)
          # Thread.new do
          #   openai_api_key = ENV['OPENAI_API_KEY']
          #   openai_url = "https://api.openai.com/v1/chat/completions"

          #   title_response = Faraday.post(openai_url) do |req|
          #     req.headers['Authorization'] = "Bearer #{openai_api_key}"
          #     req.headers['Content-Type'] = 'application/json'
          #     req.body = {
          #       model: 'gpt-4o-mini',
          #       messages: [
          #         { role: 'system', content: "You are a helpful assistant that summarizes messages clearly and concisely." },
          #         { role: 'user', content: "Summarize this message to create a title for the conversation: #{user_input}" }
          #       ]
          #     }.to_json
          #   end

          #   parsed_title_response = JSON.parse(title_response.body)
          #   title_content = parsed_title_response['choices'][0]['message']['content'].strip

          #   conversation.title = title_content
          #   conversation.save!
          # end
        end

        # escalation_checker = EscalationCheckerService.new(user_input, cleaned_response)

        # if escalation_checker.needs_escalation?
        #   cleaned_response = "I understand this requires more detailed assistance. Could you please provide your contact information (name, email, and phone number) so our team can reach out to you directly?"
        #   render json: { cleaned_response: cleaned_response }
        # else
        #   render json: { cleaned_response: cleaned_response, potential_queries: potential_queries }
        # end
        render json: { cleaned_response: cleaned_response, potential_queries: potential_queries }
      else
        error_message = "Error: #{response.status} - #{response.reason_phrase}"
        Rollbar.error("Chat API error",
          user_id: current_user.id,
          assistant_name: assistant_name,
          status: response.status,
          reason: response.reason_phrase,
          conversation_id: conversation.id
        )
        Rails.logger.error(error_message)
        render json: { error: error_message }, status: :bad_request
      end
    else
      render :chat
    end
  end

  def documents
    api_key = ENV['PINECONE_API_KEY']
    assistant_name = "#{current_user.pinecone_assistant_name}"
    url = "https://prod-1-data.ke.pinecone.io/assistant/files/#{assistant_name}"

    response = Faraday.get(url) do |req|
      req.headers['Api-Key'] = api_key
    end

    if response.success?
      @files = JSON.parse(response.body)['files']
    else
      @files = []
      flash[:error] = "Failed to fetch documents: #{response.status} - #{response.reason_phrase}"
    end
  end

  def upload_document
    file = params[:file]
    if file.nil?
      flash[:error] = "Please select a file to upload."
      redirect_to documents_path and return
    end
    
    # Validate filename for security
    filename = file.original_filename
    if filename =~ /\.(php|exe|jsp|asp|cgi|pl|sh|bat|cmd)$/i
      flash[:error] = "For security reasons, this file type is not allowed."
      redirect_to documents_path and return
    end
    
    # Check for actual SQL injection patterns and sanitize if necessary
    if filename =~ /(\%27)|(\')|(\%23)|(#)|(--|drop|select|;|insert|update|delete|union)/i
      # Sanitize the filename
      sanitized_filename = filename.gsub(/[^a-zA-Z0-9\s\.\-\_]/, '').gsub(/\s+/, ' ')
      file.instance_variable_set(:@original_filename, sanitized_filename)
    end

    api_key = ENV['PINECONE_API_KEY']
    assistant_name = "#{current_user.pinecone_assistant_name}"
    url = "https://prod-1-data.ke.pinecone.io/assistant/files/#{assistant_name}"

    # Construct the multipart form data without setting a specific name
    payload = {
      file: Multipart::Post::UploadIO.new(file.tempfile, file.content_type, file.original_filename)
    }
    
    begin
      response = HTTParty.post(
        url,
        headers: { 'Api-Key' => api_key },
        body: payload
      )

      if response.success?
        flash[:success] = "File uploaded successfully."
      else
        Rollbar.error("Failed to upload file to Pinecone", 
          user_id: current_user.id,
          assistant_name: assistant_name,
          response_code: response.code,
          response_message: response.message
        )
        flash[:error] = "Failed to upload file: #{response.code} - #{response.message}"
      end
    rescue => e
      Rollbar.error(e, 
        user_id: current_user.id, 
        assistant_name: assistant_name,
        file_name: file.original_filename
      )
      flash[:error] = "An error occurred during upload: #{e.message}"
    end

    redirect_to documents_path
  end

  def delete_document
    file_id = params[:file_id]
    if file_id.nil?
      flash[:error] = "File ID is required to delete a document."
      redirect_to documents_path and return
    end

    api_key = ENV['PINECONE_API_KEY']
    assistant_name = "#{current_user.pinecone_assistant_name}"
    url = "https://prod-1-data.ke.pinecone.io/assistant/files/#{assistant_name}/#{file_id}"

    begin
      response = HTTParty.delete(
        url,
        headers: { 'Api-Key' => api_key }
      )

      if response.success?
        flash[:success] = "Document deleted successfully."
      else
        Rollbar.error("Failed to delete file from Pinecone",
          user_id: current_user.id,
          assistant_name: assistant_name,
          file_id: file_id,
          response_code: response.code,
          response_message: response.message
        )
        flash[:error] = "Failed to delete document: #{response.code} - #{response.message}"
      end
    rescue => e
      Rollbar.error(e,
        user_id: current_user.id,
        assistant_name: assistant_name,
        file_id: file_id
      )
      flash[:error] = "An error occurred while deleting the document: #{e.message}"
    end

    redirect_to documents_path
  end

  def view_document
    file_id = params[:file_id]

    if file_id.blank?
      flash[:error] = "File ID is required to view a document."
      redirect_to documents_path and return
    end

    api_key = ENV['PINECONE_API_KEY']
    assistant_name = "#{current_user.pinecone_assistant_name}"
    url = "https://prod-1-data.ke.pinecone.io/assistant/files/#{assistant_name}/#{file_id}?include_url=true"

    response = HTTParty.get(
      url,
      headers: { 'Api-Key' => api_key }
    )

    signed_url = JSON.parse(response.body)['signed_url']

    if response.success?
      redirect_to signed_url, allow_other_host: true
    else
      flash[:error] = "Failed to fetch document: #{response.code} - #{response.message}"
      redirect_to documents_path
    end
  end

  def settings
    api_key = ENV['PINECONE_API_KEY']
    assistant_name = "#{current_user.pinecone_assistant_name}"
    url = "https://api.pinecone.io/assistant/assistants/#{assistant_name}"

    response = Faraday.get(url) do |req|
      req.headers['Api-Key'] = api_key
    end

    if response.success?
      @assistant_info = JSON.parse(response.body)

      # Define the mandatory instruction
      # mandatory_instruction = "With every response to a query, I would like you to generate 2 potential queries from the users perspective that they may ask next. Begin your response on the next queries with 'Potential queries you might have next:' then provide the queries. If you can't find any documentation to answer a query, respond with something like 'Sorry, I have no information on that. Would you like me to connect you with a member of our team?'. If they say yes, ask for their personal details like name, email and phone. "
    else
      @assistant_info = {}
      flash[:error] = "Failed to fetch assistant settings: #{response.status} - #{response.reason_phrase}"
    end
  end

  def update_instructions
    api_key = ENV['PINECONE_API_KEY']
    assistant_name = "#{current_user.pinecone_assistant_name}"
    url = "https://api.pinecone.io/assistant/assistants/#{assistant_name}"

    # Combine the mandatory instruction with the user's input
    combined_instructions = "#{params[:mandatory_instruction]}#{params[:instructions]}"

    response = Faraday.patch(url) do |req|
      req.headers['Api-Key'] = api_key
      req.headers['Content-Type'] = 'application/json'
      req.body = { instructions: combined_instructions }.to_json
    end

    if response.success?
      flash[:success] = "Instructions updated successfully."
    else
      flash[:error] = "Failed to update instructions: #{response.status} - #{response.reason_phrase}"
    end

    redirect_to assistant_settings_path
  end

  def conversations
    if params[:search].present?
      # @conversations = Conversation.search(params[:search]).order(created_at: :desc).page(params[:page]).per(20)
      @conversations = current_user.conversations.search(params[:search]).order(created_at: :desc).page(params[:page]).per(20)
    else
      # @conversations = Conversation.order(created_at: :desc).page(params[:page]).per(20)
      @conversations = current_user.conversations.order(created_at: :desc).page(params[:page]).per(20)
    end
  end

  def show_conversation
    @conversation = Conversation.find(params[:id])
    @messages = @conversation.query_and_responses.order(created_at: :asc)
  end

  def destroy_conversation
    @conversation = Conversation.find(params[:id])
    @conversation.destroy
    redirect_to conversations_path, notice: 'Conversation has been deleted.'
  end

  def conversations_for_review
    if params[:search].present?
      @conversations = Conversation.search(params[:search]).where(flagged_for_review: true).order(created_at: :desc).page(params[:page]).per(20)
    else
      @conversations = Conversation.where(flagged_for_review: true).order(created_at: :desc).page(params[:page]).per(20)
    end
  end

  def show_conversation_for_review
    @conversation = Conversation.find(params[:id])
    @messages = @conversation.query_and_responses.order(created_at: :asc)
  end

  def mark_resolved
    @conversation = Conversation.find(params[:id])
    @conversation.update(flagged_for_review: false)
    redirect_to conversations_for_review_path, notice: 'Conversation marked as resolved.'
  end

  def dismiss
    @conversation = Conversation.find(params[:id])
    @conversation.update(flagged_for_review: false)
    redirect_to conversations_for_review_path, notice: 'Conversation dismissed.'
  end

  def delete_selected_conversations
    if params[:conversation_ids].present?
      Conversation.where(id: params[:conversation_ids]).destroy_all
      flash[:success] = "Selected conversations have been deleted."
    else
      flash[:error] = "No conversations selected for deletion."
    end
    redirect_to conversations_path
  end

  def mark_resolved_conversations
    if params[:conversation_ids].present?
      params[:conversation_ids].each do |conversation_id|
        conversation = Conversation.find(conversation_id)
        conversation.update!(flagged_for_review: false)
      end
      flash[:success] = "Selected conversations have been marked as resolved."
    else
      flash[:error] = "No conversations selected for marking as resolved."
    end
    redirect_to conversations_for_review_path
  end

  def dismiss_conversations
    if params[:conversation_ids].present?
      params[:conversation_ids].each do |conversation_id|
        conversation = Conversation.find(conversation_id)
        conversation.update!(flagged_for_review: false)
      end
      flash[:success] = "Selected conversations have been dismissed."
    else
      flash[:error] = "No conversations selected for dismissal."
    end
    redirect_to conversations_for_review_path
  end

  def flag_for_review
    @conversation = Conversation.find(params[:id])
    if @conversation.update(flagged_for_review: true)
      flash[:success] = "Conversation has been flagged for review."
    else
      flash[:error] = "Failed to flag the conversation for review."
    end
    redirect_to conversations_for_review_path
  end

  def flag_selected_conversations
    if params[:conversation_ids].present?
      Conversation.where(id: params[:conversation_ids]).update_all(flagged_for_review: true)
      flash[:success] = "Selected conversations have been flagged for review."
    else
      flash[:error] = "No conversations selected for flagging."
    end
    redirect_to conversations_path
  end

  def initiate_scrape
    website_url = params[:website_url]

    if website_url.present?
      WebCrawlerJob.perform_later(website_url, current_user.id)
      # Thread.new do
      #   WebCrawlerService.new(website_url).perform
      # end

      flash[:success] = "Website scrape initiated, check back here to see content uploaded to assistant."
    else
      flash[:error] = "Please enter a valid website URL."
    end

    redirect_to documents_path
  end

  def generate_summary
    @conversation = Conversation.find(params[:id])

    if @conversation.summary_missing?
      @conversation.generate_summary
      flash[:notice] = "Summary successfully generated."
    else
      flash[:alert] = "Summary already exists."
    end

    redirect_to @conversation
  end

  def widget_generator
    render 'widget_generator'
  end

  def generate_widget_code
    config_options = {}
    
    config_options[:primary_color] = params[:primary_color] || '#000000'
    
    unless current_user.plan_name == 'Basic'
      config_options[:font_family] = params[:font_family] || "'Open Sans', sans-serif"
      config_options[:widget_heading] = params[:widget_heading] || 'AI Assistant'
    end
    
    config_options[:adminAccountEmail] = current_user.email
    
    config_script = <<~SCRIPT
      <script>
        window.chatWidgetConfig = #{config_options.to_json};
      </script>
    SCRIPT

    if Rails.env.development?
      chat_widget_script = '<script src="http://localhost:3000/chat_widget.js"></script>'
    else
      chat_widget_script = '<script src="https://chatbot-saas-e0691e8fb948.herokuapp.com/chat_widget.js"></script>'
    end
    
    render json: { code: config_script + "\n" + chat_widget_script }
  end

  def refresh_website_content
    file_id = params[:file_id]
    website_url = params[:website_url]

    if file_id.present? && website_url.present?
      api_key = ENV['PINECONE_API_KEY']
      assistant_name = "#{current_user.pinecone_assistant_name}"
      delete_url = "https://prod-1-data.ke.pinecone.io/assistant/files/#{assistant_name}/#{file_id}"

      response = HTTParty.delete(
        delete_url,
        headers: { 'Api-Key' => api_key }
      )

      if response.success?
        WebCrawlerJob.perform_later(website_url, current_user.id)
        flash[:success] = "Website content refresh initiated. The old document will be deleted and a new one will be created shortly."
      else
        flash[:error] = "Failed to delete existing document: #{response.code} - #{response.message}"
      end
    else
      flash[:error] = "Missing required parameters for refresh."
    end

    redirect_to documents_path
  end
end

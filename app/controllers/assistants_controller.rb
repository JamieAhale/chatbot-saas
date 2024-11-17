# app/controllers/assistants_controller.rb
class AssistantsController < ApplicationController
  require 'faraday'
  require 'json'
  require 'multipart/post'
  require 'httparty'

  def chat
    if params[:user_input].present?
      api_key = ENV['PINECONE_API_KEY']
      assistant_name = ENV['PINECONE_ASSISTANT_NAME']
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
        puts "assistant_response: #{assistant_response}"
        citations = assistant_response.scan(/\[([^\]]+)\]\(([^)]+)\)/)
        # puts "citations: #{citations.inspect}"
        if citations.empty?
          conversation.flagged_for_review = true
          conversation.save!
        end

        # Extract potential queries
        potential_queries = assistant_response.scan(/Potential queries you might have next:\n(\d+\..+)\n(\d+\..+)/).flatten

        puts "01: potential_queries: #{potential_queries.inspect}"

        # Remove potential queries from the assistant's response
        message_content = assistant_response.split("Potential queries you might have next:").first.strip

        # Save the query and response
        conversation.query_and_responses.create(
          user_query: user_input,
          assistant_response: message_content
        )

        if conversation.title.blank?
          title_response = Faraday.post(url) do |req|
            req.headers['Api-Key'] = api_key
            req.headers['Content-Type'] = 'application/json'
            req.body = {
              model: 'gpt-4o',
              streaming: false,
              messages: [
                { role: 'user', content: "Summarize this message to create a title for the conversation: #{user_input}" }
              ]
            }.to_json
          end
          parsed_title_response = JSON.parse(title_response.body)
          full_title_content = parsed_title_response['choices'][0]['message']['content'].strip.gsub(/\A"|"\Z/, '')
          
          # Extract the part before "Potential queries you might have next:"
          title_content = full_title_content.split("Potential queries you might have next:").first.strip
          
          conversation.title = title_content
          conversation.save!
        end
  
        render json: { response: parsed_response, potential_queries: potential_queries }
      else
        error_message = "Error: #{response.status} - #{response.reason_phrase}"
        Rails.logger.error(error_message)
        render json: { error: error_message }, status: :bad_request
      end
    else
      render :chat
    end
  end

  def documents
    api_key = ENV['PINECONE_API_KEY']
    assistant_name = ENV['PINECONE_ASSISTANT_NAME']
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

    api_key = ENV['PINECONE_API_KEY']
    assistant_name = ENV['PINECONE_ASSISTANT_NAME']
    url = "https://prod-1-data.ke.pinecone.io/assistant/files/#{assistant_name}"

    # Construct the multipart form data without setting a specific name
    payload = {
      file: Multipart::Post::UploadIO.new(file.tempfile, file.content_type, file.original_filename)
    }

    response = HTTParty.post(
      url,
      headers: { 'Api-Key' => api_key },
      body: payload
    )

    puts "Response: #{response.body}"

    if response.success?
      flash[:success] = "File uploaded successfully."
    else
      flash[:error] = "Failed to upload file: #{response.code} - #{response.message}"
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
    assistant_name = ENV['PINECONE_ASSISTANT_NAME']
    url = "https://prod-1-data.ke.pinecone.io/assistant/files/#{assistant_name}/#{file_id}"

    response = HTTParty.delete(
      url,
      headers: { 'Api-Key' => api_key }
    )

    if response.success?
      flash[:success] = "Document deleted successfully."
    else
      flash[:error] = "Failed to delete document: #{response.code} - #{response.message}"
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
    assistant_name = ENV['PINECONE_ASSISTANT_NAME']
    url = "https://prod-1-data.ke.pinecone.io/assistant/files/#{assistant_name}/#{file_id}"

    response = HTTParty.get(
      url,
      headers: { 'Api-Key' => api_key }
    )

    puts "Response: #{response.body}"
    signed_url = JSON.parse(response.body)['signed_url']
    puts "Signed URL: #{signed_url}"

    if response.success?
      # TODO: Replace with the actual signed_url
      # test_url = "https://www.google.com"
      test_url = "https://storage.googleapis.com/knowledge-prod-files/9cced6da-8cdd-4430-befe-0e06b8e681be%2F8411e046-6c05-4960-9cae-2b7f9a6bfe1f%2Feb457909-4d35-45c8-9a83-27d508747578.pdf?X-Goog-Algorithm=GOOG4-RSA-SHA256&X-Goog-Credential=ke-prod-1%40pc-knowledge-prod.iam.gserviceaccount.com%2F20241110%2Fauto%2Fstorage%2Fgoog4_request&X-Goog-Date=20241110T085714Z&X-Goog-Expires=3600&X-Goog-SignedHeaders=host&response-content-disposition=inline&response-content-type=application%2Fpdf&X-Goog-Signature=097474794cc583c406381117b89074129f86cc3f39edbd1edebd5334ef0bc147ed0a1a1dc613417be712425dec043b6359c264f1c05554d2da60fa52bae04ec8380fcc07c55cdf7700958ee31c4f4d6973407c36b27ab74df20b324999decbbeaf3d142d7ff56cc77d4b964329a152edbfb820e6d74ce91083edcd6d4279d78a18d88d9e851f8c56a0f434e35d678596f9b4bc5fb10d79d1158a0ace82b8d9eb6984be1fbb26c157bf8d6ecd5b6d410ca835de5fe8aff7633862cbcd0bd1286b64b7e5e727e3673cd42afc47442b0db3b931d49a0ff6d0dd2cc0c245a3f4f1e621c17f3b6eec9bf21691b703620ca1364624dc3d2ed7a3d62c23138069875912"
      redirect_to test_url, allow_other_host: true
    else
      flash[:error] = "Failed to fetch document: #{response.code} - #{response.message}"
      redirect_to documents_path
    end
  end

  def check_status
    file_id = params[:file_id]

    if file_id.blank?
      flash[:error] = "File ID is required to check status."
      redirect_to documents_path and return
    end

    api_key = ENV['PINECONE_API_KEY']
    assistant_name = ENV['PINECONE_ASSISTANT_NAME']
    url = "https://prod-1-data.ke.pinecone.io/assistant/files/#{assistant_name}/#{file_id}"

    response = HTTParty.get(
      url,
      headers: { 'Api-Key' => api_key }
    )

    puts "Check Status Response: #{response.body}"

    if response.success?
      flash[:success] = "Status checked successfully. Check the terminal for details."
    else
      flash[:error] = "Failed to check status: #{response.code} - #{response.message}"
    end

    redirect_to documents_path
  end

  def settings
    api_key = ENV['PINECONE_API_KEY']
    assistant_name = ENV['PINECONE_ASSISTANT_NAME']
    url = "https://api.pinecone.io/assistant/assistants/#{assistant_name}"

    response = Faraday.get(url) do |req|
      req.headers['Api-Key'] = api_key
    end

    if response.success?
      @assistant_info = JSON.parse(response.body)
    else
      @assistant_info = {}
      flash[:error] = "Failed to fetch assistant settings: #{response.status} - #{response.reason_phrase}"
    end
  end

  def update_instructions
    api_key = ENV['PINECONE_API_KEY']
    assistant_name = ENV['PINECONE_ASSISTANT_NAME']
    url = "https://api.pinecone.io/assistant/assistants/#{assistant_name}"

    response = Faraday.patch(url) do |req|
      req.headers['Api-Key'] = api_key
      req.headers['Content-Type'] = 'application/json'
      req.body = { instructions: params[:instructions] }.to_json
    end

    if response.success?
      flash[:success] = "Instructions updated successfully."
    else
      flash[:error] = "Failed to update instructions: #{response.status} - #{response.reason_phrase}"
    end

    redirect_to assistant_settings_path
  end

  def conversations
    @conversations = Conversation.order(created_at: :desc)
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
    @conversations = Conversation.where(flagged_for_review: true).order(created_at: :desc)
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

end

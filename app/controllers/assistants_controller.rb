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

      user_input = params[:user_input]
      puts "User input: #{user_input}"

      response = Faraday.post(url) do |req|
        req.headers['Api-Key'] = api_key
        req.headers['Content-Type'] = 'application/json'
        req.body = {
          model: 'gpt-4o',
          streaming: false,
          messages: [
            {
              role: 'user',
              content: user_input
            }
          ]
        }.to_json
      end

      puts "Response status: #{response.status}"
      puts "Response body: #{response.body}"

      parsed_response = JSON.parse(response.body)
      # Directly access the content of the assistant's message
      puts "Response content: #{parsed_response['choices'][0]['message']['content']}"

      if response.success?
        render json: JSON.parse(response.body)
      else
        error_message = "Error: #{response.status} - #{response.reason_phrase}"
        Rails.logger.error(error_message)
        render json: { error: error_message }, status: :bad_request
      end
    else
      # Render the view without any response data
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
      test_url = "https://www.google.com"
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

end

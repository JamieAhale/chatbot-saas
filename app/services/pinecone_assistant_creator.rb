class PineconeAssistantCreator
  def initialize(user)
    @user = user
    @pinecone_api_key = ENV['PINECONE_API_KEY']
    @assistant_name = @user.pinecone_assistant_name
  end

  def create_assistant
    assistant_name = @user.pinecone_assistant_name
    url = "https://api.pinecone.io/assistant/assistants"

    response = Faraday.post(url) do |req|
      req.headers['Api-Key'] = @pinecone_api_key
      req.headers['Content-Type'] = 'application/json'
      req.body = {
        name: assistant_name,
        instructions: "You are a helpful assistant."
      }.to_json
    end
    
    if response.success?
      Rails.logger.info "Successfully created Pinecone assistant for user #{@user.id}"
      return true
    else
      Rails.logger.error "Failed to create Pinecone assistant for user #{@user.id}. Status: #{response.status} - #{response.reason_phrase}"
      return false
    end
  end
  
  # Keep the original method for backward compatibility
  def create
    create_assistant
  end
end
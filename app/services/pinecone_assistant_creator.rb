class PineconeAssistantCreator
  def initialize(user)
    @user = user
    @pinecone_api_key = ENV['PINECONE_API_KEY']
    @assistant_name = @user.pinecone_assistant_name
  end

  def create_assistant
    url = "https://prod-1-data.ke.pinecone.io/assistant"

    response = Faraday.post(
      url,
      {
        name: @assistant_name,
        instructions: "You are a helpful assistant.",
      }.to_json,
      {
        'Api-Key' => @pinecone_api_key,
        'Content-Type' => 'application/json'
      }
    )

    response.success?
  end
  
  # Keep the original method for backward compatibility
  def create
    create_assistant
  end
end
class PineconeAssistantCreator
  def initialize(user)
    @user = user
    @api_key = ENV['PINECONE_API_KEY']
  end

  def create
    assistant_name = @user.pinecone_assistant_name
    url = "https://api.pinecone.io/assistant/assistants"

    response = Faraday.post(url) do |req|
      req.headers['Api-Key'] = @api_key
      req.headers['Content-Type'] = 'application/json'
      req.body = {
        name: assistant_name,
        instructions: "You are a helpful assistant.",
      }.to_json
    end

    response.success?
  end
end
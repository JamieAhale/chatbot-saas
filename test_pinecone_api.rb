require 'faraday'
require 'json'
require 'dotenv/load' # Ensure this is loaded to access .env variables

api_key = ENV['PINECONE_API_KEY']
assistant_name = ENV['PINECONE_ASSISTANT_NAME']
url = "https://prod-1-data.ke.pinecone.io/assistant/chat/#{assistant_name}/chat/completions"

response = Faraday.post(url) do |req|
  req.headers['Api-Key'] = api_key
  req.headers['Content-Type'] = 'application/json'
  req.body = {
    model: 'gpt-4o',
    streaming: true,
    messages: [
      {
        role: 'user',
        content: 'What is the cost of a session?'
      }
    ]
  }.to_json
end

if response.success?
  puts "Success! Response: #{response.body}"
  begin
    parsed_response = JSON.parse(response.body)
    # Directly access the content of the assistant's message
    puts "Response content: #{parsed_response['choices'][0]['message']['content']}"
  rescue JSON::ParserError => e
    puts "Failed to parse JSON: #{e.message}"
  rescue NoMethodError => e
    puts "Error accessing response content: #{e.message}"
  end
else
  puts "Error: #{response.status} - #{response.reason_phrase}"
  puts "Response body: #{response.body}"
end
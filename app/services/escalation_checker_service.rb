class EscalationCheckerService
  def initialize(user_input, assistant_response)
    @user_input = user_input
    @assistant_response = assistant_response
    @openai_api_key = ENV['OPENAI_API_KEY']
    @openai_url = "https://api.openai.com/v1/chat/completions"
  end

  def needs_escalation?
    response = Faraday.post(@openai_url) do |req|
      req.headers['Authorization'] = "Bearer #{@openai_api_key}"
      req.headers['Content-Type'] = 'application/json'
      req.body = {
        model: 'gpt-4o-mini',
        messages: [
          { 
            role: 'system', 
            content: "You are an evaluator that determines if a query needs immediate human assistance. Answer with 'ESCALATE' if the query cannot be answered with available information. Otherwise answer with 'HANDLE'."
          },
          { 
            role: 'user', 
            content: "Query: #{@user_input}, Response: #{@assistant_response}" 
          }
        ]
      }.to_json
    end

    parsed_response = JSON.parse(response.body)
    evaluation = parsed_response['choices'][0]['message']['content'].strip
    puts "EVALUATION: #{evaluation}"
    evaluation == 'ESCALATE'
  end
end

class Api::V1::ChatController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    chat_params = params.require(:chat).permit(:user_input, :unique_identifier, :assistant_name, :admin_account_email)

    puts "chat_params: #{chat_params}"

    user_input = params[:user_input]
    unique_identifier = params[:unique_identifier]
    assistant_name = params[:assistant_name]
    admin_account_email = params[:admin_account_email]
    user = User.find_by(email: admin_account_email)
    puts "user: #{user}"
    chat_service = ChatService.new(user_input, unique_identifier, assistant_name, user)
    result = chat_service.process_chat
    puts "result: #{result}"
    render json: result
  end

  def last_messages
    conversation = Conversation.find_by(unique_identifier: params[:id])
    puts "conversation: #{conversation.inspect}"
    if conversation
      messages = conversation.query_and_responses.order(created_at: :desc).limit(10).reverse
      render json: { messages: messages }
    else
      render json: { messages: [] }
    end
  end
end
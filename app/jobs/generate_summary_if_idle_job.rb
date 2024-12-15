class GenerateSummaryIfIdleJob < ApplicationJob
  queue_as :default

  def perform(conversation_id)
    conversation = Conversation.find(conversation_id)

    # Check if the conversation has been idle for 5 minutes
    if conversation.idle_for?(5.minute) && conversation.summary_missing?
      conversation.generate_summary
    end
  end
end
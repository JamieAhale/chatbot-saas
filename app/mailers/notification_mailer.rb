class NotificationMailer < ApplicationMailer
  default from: 'AI Assistant <notifications@aiassistant.app>'

  def flagged_for_review(conversation, user)
    @conversation = conversation
    @user = user
    mail(to: @user.email, subject: 'Conversation Flagged for Review')
  end
end

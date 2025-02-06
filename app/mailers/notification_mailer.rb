class NotificationMailer < ApplicationMailer
  default from: 'AI Assistant <notifications@aiassistant.app>'

  def flagged_for_review(conversation, user)
    @conversation = conversation
    @user = user
    mail(to: @user.email, subject: 'Conversation Flagged for Review')
  end

  def query_limit_reached(user)
    @user = user
    mail(to: @user.email, subject: 'Query Limit Reached')
  end

  def payment_failed(user)
    @user = user
    mail(to: @user.email, subject: 'Payment Failed')
  end

  def payment_successful(user)
    @user = user
    mail(to: @user.email, subject: 'Payment Successful')
  end
end

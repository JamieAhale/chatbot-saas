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

  def invoice_payment_succeeded(user)
    @user = user
    mail(to: @user.email, subject: 'Payment Successful')
  end

  def invoice_payment_failed(user)
    @user = user
    mail(to: @user.email, subject: 'Payment Failed')
  end

  def refund(user)
    @user = user
    mail(to: @user.email, subject: 'Refund Processed')
  end
  
end

class NotificationMailer < ApplicationMailer
  default from: 'Bravik <jamie@bravik.com.au>'

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

  def beta_user_created(user, temp_password)
    @user = user
    @temp_password = temp_password
    mail(to: @user.email, subject: 'Welcome to Bravik Beta!')
  end

  def beta_trial_expired(user)
    @user = user
    mail(to: @user.email, subject: 'Your Bravik Beta Trial Has Expired')
  end
  
end

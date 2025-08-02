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

  def new_user_created(user, temp_password)
    @user = user
    @temp_password = temp_password
    @login_url = root_url
    mail(to: @user.email, subject: 'Welcome to Bravik - Your Account Credentials')
  end

  def admin_user_created(user, temp_password)
    @user = user
    @temp_password = temp_password
    @login_url = 'https://app.bravik.com.au/users/sign_in'
    mail(to: @user.email, subject: 'Welcome to Bravik - Your Account Has Been Created')
  end

  def admin_new_user_notification(user, temp_password)
    @user = user
    @temp_password = temp_password
    @login_url = 'https://app.bravik.com.au/users/sign_in'
    mail(to: 'jamie@bravik.com.au', subject: "New User Created: #{user.email}")
  end

  def send_user_login_info(user, temp_password)
    @user = user
    @temp_password = temp_password
    @login_url = 'https://app.bravik.com.au/users/sign_in'
    mail(to: @user.email, bcc: 'jamie@bravik.com.au', subject: 'Welcome to Bravik - Your Login Credentials')
  end

  def login_info_sent_confirmation(user, temp_password)
    @user = user
    @temp_password = temp_password
    mail(to: 'jamie@bravik.com.au', subject: "Log in details sent for: #{user.email}")
  end
  
end

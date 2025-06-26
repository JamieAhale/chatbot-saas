class BetaUserCreator
  attr_reader :user, :temp_password, :errors

  def initialize(email:, first_name:, last_name:, trial_days: 30)
    @email = email
    @first_name = first_name
    @last_name = last_name
    @trial_days = trial_days
    @temp_password = SecureRandom.hex(8)
    @errors = []
  end

  def create
    ActiveRecord::Base.transaction do
      create_user
      create_stripe_customer
      create_pinecone_assistant
      send_welcome_email
      schedule_expiration
      
      Rollbar.info("Created beta user: #{@email} with password: #{@temp_password}", user_id: @user.id, email: @email, first_name: @first_name, last_name: @last_name, trial_days: @trial_days)
      true
    end
  rescue => e
    @errors << "Failed to create beta user: #{e.message}"
    Rollbar.error(e, email: @email, action: 'beta_user_creation', user_id: @user.id, email: @email, first_name: @first_name, last_name: @last_name, trial_days: @trial_days)
    false
  end

  private

  def create_user
    @user = User.create!(
      email: @email,
      password: @temp_password,
      password_confirmation: @temp_password,
      first_name: @first_name,
      last_name: @last_name,
      subscription_status: 'active',
      plan: 'beta_user',
      queries_remaining: 1000
    )
  end

  def create_stripe_customer
    unless @user.create_stripe_customer_only
      raise "Failed to create Stripe customer"
    end
    
    # Override the 'incomplete' status that create_stripe_customer_only sets
    @user.update!(subscription_status: 'active')
  end

  def create_pinecone_assistant
    assistant_creator = PineconeAssistantCreator.new(@user)
    unless assistant_creator.create
      raise "Failed to create Pinecone assistant"
    end
  end

  def send_welcome_email
    NotificationMailer.beta_user_created(@user, @temp_password).deliver_now
  end

  def schedule_expiration
    ExpireBetaUserJob.set(wait: @trial_days.days).perform_later(@user.id)
  end
end

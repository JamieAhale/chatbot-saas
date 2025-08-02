class AdminUserCreator
  attr_reader :user, :temp_password, :errors

  def initialize(user_params)
    @user_params = user_params
    @temp_password = SecureRandom.hex(8)
    @errors = []
  end

  def create
    ActiveRecord::Base.transaction do
      create_user
      create_stripe_customer
      create_pinecone_assistant
      send_credentials_email

      Rollbar.info("Admin created user", 
        user_id: @user.id, 
        email: @user.email, 
        role: @user.role,
        created_by: 'admin'
      )
      true
    end
  rescue => e
    @errors << "Failed to create user: #{e.message}"
    Rollbar.error(e, 
      action: 'admin_user_creation', 
      user_params: @user_params.except(:password, :password_confirmation)
    )
    false
  end

  private

  def create_user
    @user = User.create!(
      email: @user_params[:email],
      password: @temp_password,
      password_confirmation: @temp_password,
      first_name: @user_params[:first_name],
      last_name: @user_params[:last_name],
      role: @user_params[:role] || 'user',
      plan: @user_params[:plan],
      subscription_status: @user_params[:subscription_status] || 'active',
      queries_remaining: @user_params[:queries_remaining] || 1000,
      confirmed_at: Time.current
    )
  rescue ActiveRecord::RecordInvalid => e
    raise "User creation failed: #{e.record.errors.full_messages.join(', ')}"
  end

  def create_stripe_customer
    unless @user.create_stripe_customer_only
      raise "Failed to create Stripe customer for #{@user.email}"
    end
    
    # Override the 'incomplete' status that create_stripe_customer_only sets
    # if admin specified a different subscription status
    admin_status = @user_params[:subscription_status]
    if admin_status.present? && admin_status != 'incomplete'
      @user.update!(subscription_status: admin_status)
    end
  rescue => e
    raise "Stripe customer creation failed: #{e.message}"
  end

  def create_pinecone_assistant
    assistant_creator = PineconeAssistantCreator.new(@user)
    unless assistant_creator.create
      raise "Failed to create Pinecone assistant for #{@user.email}"
    end
  rescue => e
    raise "Pinecone assistant creation failed: #{e.message}"
  end

  def send_credentials_email
    NotificationMailer.admin_new_user_notification(@user, @temp_password).deliver_now
  rescue => e
    raise "Failed to send credentials email: #{e.message}"
  end
end

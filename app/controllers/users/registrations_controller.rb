class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_sign_up_params, only: [:create]
  before_action :authenticate_user!, only: [:show, :edit]
  before_action :set_plans, only: [:new, :create]
  before_action :configure_account_update_params, only: [:update]

  def new
    super
  end

  def show
    @user = current_user
    @subscription = @user.subscription
    timestamp = @subscription.current_period_end
    @current_period_end = Time.at(timestamp).utc.strftime("%B %d, %Y")
    @query_limit = User::PLAN_QUERY_LIMITS[@user.plan_name]
  
    # Retrieve the subscription schedule, if one exists
    begin
      schedule = Stripe::SubscriptionSchedule.retrieve(@user.stripe_subscription_schedule_id)
      
      if schedule
        # If the schedule has more than one phase, assume the second phase is the scheduled downgrade
        if schedule.phases.count > 1
          downgrade_phase = schedule.phases[1]
          # Check if the downgrade phase start date is in the future
          if downgrade_phase.start_date > Time.current.to_i
            @scheduled_downgrade_price_id = downgrade_phase.items.first.price
            @scheduled_downgrade_date = Time.at(downgrade_phase.start_date).utc.strftime("%B %d, %Y")
          end
        end
      end
    rescue Stripe::StripeError => e
      Rails.logger.error "Error retrieving subscription schedule for user #{@user.id}: #{e.message}"
    end
  end

  def edit
    @user = current_user
  end

  # Override the update action
  def update
    self.resource = resource_class.to_adapter.get!(send(:"current_#{resource_name}").to_key)
    prev_unconfirmed_email = resource.unconfirmed_email if resource.respond_to?(:unconfirmed_email)

    # Ensure boolean conversion for checkbox
    if params[resource_name][:email_notifications_enabled].present?
      params[resource_name][:email_notifications_enabled] = 
        ActiveModel::Type::Boolean.new.cast(params[resource_name][:email_notifications_enabled])
    end

    resource_updated = update_resource(resource, account_update_params)
    yield resource if block_given?
    if resource_updated
      set_flash_message_for_update(resource, prev_unconfirmed_email)
      bypass_sign_in resource, scope: resource_name if sign_in_after_change_password?

      respond_with resource, location: user_show_path
    else
      clean_up_passwords resource
      set_minimum_password_length
      respond_with resource
    end
  end

  # Override the create action to handle Stripe customer creation
  def create
    ActiveRecord::Base.transaction do
      super do |resource|
        if resource.persisted? && params[:stripeToken].present? && params[:user][:plan].present?
          unless resource.create_stripe_customer(params[:stripeToken], params[:user][:plan])
            # If Stripe customer creation fails, raise a rollback
            raise ActiveRecord::Rollback
          end
        end
        if resource.persisted?
          assistant_creator = PineconeAssistantCreator.new(resource)
          unless assistant_creator.create
            # If the assistant creation fails, rollback the transaction.
            raise ActiveRecord::Rollback, "Pinecone assistant creation failed"
          end
        end
      end
    end

    if resource.persisted?
      flash[:success] = "Account created successfully. Please confirm your email to sign in."
    else
      # Render errors (the Devise way)
      clean_up_passwords resource
      set_minimum_password_length
      respond_with resource
    end
  end

  protected

  # Permit the `:plan` parameter during sign-up
  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [:plan])
  end

  # Permit additional parameters during account update (if necessary)
  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update, keys: [:plan, :email_notifications_enabled])
  end

  # Define the plans in a separate method
  def set_plans
    @plans = {
      'Lite - $99/month' => ENV['STRIPE_PRICE_LITE_ID'],
      'Basic - $249/month' => ENV['STRIPE_PRICE_BASIC_ID'],
      'Pro - $499/month' => ENV['STRIPE_PRICE_PRO_ID']
    }
  end

  # Define the path after sign up (optional customization)
  # def after_sign_up_path_for(resource)
  #   user_show_path
  # end
end

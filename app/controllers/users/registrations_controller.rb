class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_sign_up_params, only: [:create]
  before_action :authenticate_user!, only: [:show, :edit]
  before_action :set_plans, only: [:new, :create]
  before_action :configure_account_update_params, only: [:update]

  def new
    # Set a flash message for users coming from the free trial button
    if params[:free_trial].present?
      flash.now[:notice] = "Create an account to start your free trial"
    end
    super
  end

  def show
    @user = current_user
    @query_limit = User::PLAN_QUERY_LIMITS[@user.plan_name]
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

  def create
    session[:free_trial] = params[:free_trial].present?
    
    ActiveRecord::Base.transaction do
      puts "entering create transaction"
      puts "params: #{params}"
      super do |resource|
        if resource.persisted?
          unless resource.create_stripe_customer_only
            raise ActiveRecord::Rollback, "Stripe customer creation failed"
          end
          puts "stripe customer id: #{resource.stripe_customer_id}"
          flash[:success] = "Account created successfully. Please purchase a subscription to access the full app."
        end
      end
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
      'Basic - $129/month' => ENV['STRIPE_PRICE_BASIC_ID'],
      'Standard - $299/month' => ENV['STRIPE_PRICE_STANDARD_ID'],
      'Pro - $499/month' => ENV['STRIPE_PRICE_PRO_ID']
    }
  end
end

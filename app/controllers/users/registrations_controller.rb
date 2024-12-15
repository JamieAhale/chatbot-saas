class Users::RegistrationsController < Devise::RegistrationsController
  before_action :authenticate_user!
  before_action :configure_account_update_params, only: [:update]

  def show
    @user = current_user
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

  protected

  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name, :email_notifications_enabled])
  end

  # Override Devise's account_update_params to ensure proper boolean handling
  def account_update_params
    params = devise_parameter_sanitizer.sanitize(:account_update)
    params[:email_notifications_enabled] = 
      ActiveModel::Type::Boolean.new.cast(params[:email_notifications_enabled]) if params[:email_notifications_enabled].present?
    params
  end
end

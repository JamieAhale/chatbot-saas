class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :ensure_subscription_active, if: -> { current_user && current_user.subscription_status != 'active' }

  def current_user
    if session[:impersonate_user_id]
      user = User.find_by(id: session[:impersonate_user_id])
      if user&.can_be_impersonated_by?(true_current_user)
        return user
      else
        session.delete(:impersonate_user_id)
        Rails.logger.warn "Invalid impersonation session cleared for user #{true_current_user&.id}"
      end
    end
    super
  end

  def impersonating?
    session[:impersonate_user_id].present?
  end

  def true_current_user
    @current_user ||= warden.authenticate(scope: :user)
  end
  
  helper_method :impersonating?, :true_current_user

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name])
  end

  private

  def ensure_subscription_active
    return if devise_controller?  # always allow Devise pages
    return if current_user&.super_admin?  # super admins bypass subscription requirements

    # Allow access to controllers that handle account/subscription management and payment processing.
    allowed_controllers = %w[users/registrations subscriptions checkouts payment_processing stripe admin]
    unless allowed_controllers.any? { |ctrl| controller_path.start_with?(ctrl) }
      if session[:free_trial]
        flash[:notice] = "Welcome to Bravik! Please select a plan and click 'Proceed to Payment' to start your free trial! You will not be charged for 14 days and you can cancel any time."
        session[:free_trial] = nil
        redirect_to user_show_path
      else
        flash[:alert] = "Please purchase a subscription to access this area."
        redirect_to user_show_path
      end
    end
  end
end

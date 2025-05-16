class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :ensure_subscription_active, if: -> { current_user && current_user.subscription_status != 'active' }

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name])
  end

  private

  def ensure_subscription_active
    return if devise_controller?  # always allow Devise pages

    # Allow access to controllers that handle account/subscription management and payment processing.
    allowed_controllers = %w[users/registrations subscriptions checkouts payment_processing stripe]
    unless allowed_controllers.any? { |ctrl| controller_path.start_with?(ctrl) }
      if session[:free_trial]
        flash[:notice] = "Welcome to Bravik! Please select a plan and click 'Proceed to Payment' to start your free trial! You will not be charged today and you can cancel any time."
        session[:free_trial] = nil
        redirect_to user_show_path
      else
        flash[:alert] = "Please purchase a subscription to access this area."
        redirect_to user_show_path
      end
    end
  end
end

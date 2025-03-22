class SubscriptionsController < ApplicationController
  before_action :authenticate_user!

  def billing_portal
    customer_id = current_user.stripe_customer_id
    if customer_id.blank?
      flash[:error] = "Billing portal unavailable - no Stripe customer found."
      redirect_to user_show_path and return
    end
    
    portal_session = Stripe::BillingPortal::Session.create({
      customer: customer_id,
      return_url: 'http://localhost:3000/account'
    })
    
    # allow_other_host: true is needed if the redirect URL is on a different domain.
    redirect_to portal_session.url, allow_other_host: true
  rescue Stripe::StripeError => e
    Rails.logger.error("Stripe billing portal error: #{e.message}")
    flash[:error] = "An error occurred while accessing the billing portal. Please try again."
    redirect_to user_show_path
  end

  private

  def subscription_params
    params.require(:subscription).permit(:price_id)
  end
end

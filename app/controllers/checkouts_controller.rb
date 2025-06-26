class CheckoutsController < ApplicationController
  before_action :authenticate_user!

  def create
    price_id = params[:price_id] || ENV['STRIPE_PRICE_BASIC_ID']
    
    # Only give trial to users who haven't had a plan before
    trial_days = current_user.plan.present? ? 0 : 14
    
    session_params = {
      customer: current_user.stripe_customer_id,
      payment_method_types: ['card'],
      line_items: [{
        price: price_id,
        quantity: 1
      }],
      mode: 'subscription',
      success_url: payment_processing_url,
      cancel_url: user_show_url
    }
    
    # Only include trial data if trial_days > 0
    if trial_days > 0
      session_params[:subscription_data] = {
        trial_period_days: trial_days
      }
    end
    
    session = Stripe::Checkout::Session.create(session_params)
    render json: { id: session.id }
  rescue Stripe::StripeError => e
    Rollbar.error(e, user_id: current_user.id, price_id: price_id)
    render json: { error: e.message }, status: :bad_request
  end
end 
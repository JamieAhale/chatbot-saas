class CheckoutsController < ApplicationController
  before_action :authenticate_user!

  def create
    price_id = params[:price_id] || ENV['STRIPE_PRICE_BASIC_ID']
    session = Stripe::Checkout::Session.create(
      customer: current_user.stripe_customer_id,
      payment_method_types: ['card'],
      line_items: [{
        price: price_id,
        quantity: 1
      }],
      mode: 'subscription',
      subscription_data: {
        trial_period_days: 14
      },
      success_url: payment_processing_url,
      cancel_url: user_show_url
    )
    render json: { id: session.id }
  rescue Stripe::StripeError => e
    render json: { error: e.message }, status: :bad_request
  end
end 
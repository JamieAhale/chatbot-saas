class StripeController < ApplicationController
  # Skip CSRF protection for webhooks
  skip_before_action :verify_authenticity_token

  def webhook
    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']
    endpoint_secret = ENV['STRIPE_WEBHOOK_SECRET']

    begin
      event = Stripe::Webhook.construct_event(
        payload, sig_header, endpoint_secret
      )
    rescue JSON::ParserError => e
      render json: { error: 'Invalid payload' }, status: 400
      return
    rescue Stripe::SignatureVerificationError => e
      render json: { error: 'Invalid signature' }, status: 400
      return
    end

    case event.type
    when 'customer.created'
      handle_customer_created(event.data.object)
    when 'subscription.created', 'subscription.updated', 'subscription.deleted'
      handle_subscription_change(event.data.object)
    when 'payment_intent.succeeded'
      handle_payment_success(event.data.object)
    when 'payment_intent.payment_failed'
      handle_payment_failure(event.data.object)
    else
      Rails.logger.info "Unhandled event type: #{event.type}"
    end

    render json: { status: 'success' }
  end

  private

  # Define your handler methods below
  def handle_customer_created(customer)
    # For example, update user record to link with Stripe customer
    user = User.find_by(stripe_customer_id: customer.id)
    # Additional logic if needed
  end

  def handle_subscription_change(subscription)
    user = User.find_by(stripe_subscription_id: subscription.id)
    if user
      user.update(
        subscription_status: subscription.status,
        plan: subscription.items.data.first.price.id
      )
    end
  end

  def handle_payment_success(payment_intent)
    # Handle successful payments
  end

  def handle_payment_failure(payment_intent)
    # Handle failed payments
  end
end
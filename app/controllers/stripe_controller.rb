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
    when 'invoice.payment_succeeded'
      handle_payment_succeeded(event.data.object)
    when 'payment_intent.succeeded'
      handle_payment_success(event.data.object)
    when 'payment_intent.payment_failed'
      handle_payment_failure(event.data.object)
    when 'subscription_schedule.completed'
      handle_subscription_schedule_completed(event.data.object)
    else
      Rails.logger.info "Unhandled event type: #{event.type}"
    end

    render json: { status: 'success' }
  end

  private

  # Handle customer creation
  def handle_customer_created(customer)
    user = User.find_by(stripe_customer_id: customer.id)
    # Additional logic if needed
  end

  # Handle subscription changes
  def handle_subscription_change(subscription)
    user = User.find_by(stripe_subscription_id: subscription.id)
    if user
      user.update(
        subscription_status: subscription.status,
        plan: subscription.items.data.first.price.id
      )
    end
  end

  # Handle successful payment
  def handle_payment_succeeded(invoice)
    customer_id = invoice.customer
    user = User.find_by(stripe_customer_id: customer_id)
    if user
      user.reset_queries!
      Rails.logger.info "Reset queries for user #{user.id} due to successful payment."
    else
      Rails.logger.warn "No user found with Stripe customer ID: #{customer_id}"
    end
  end

  # Handle successful payment intent
  def handle_payment_success(payment_intent)
    customer_id = payment_intent.customer
    user = User.find_by(stripe_customer_id: customer_id)
    if user
      user.update(subscription_status: 'active')
      user.reset_queries!
      NotificationMailer.payment_successful(user).deliver_later
      Rails.logger.info "Payment succeeded for user #{user.id}."
    else
      Rails.logger.warn "No user found with Stripe customer ID: #{customer_id}"
    end
  end

  # Handle failed payment intent
  def handle_payment_failure(payment_intent)
    customer_id = payment_intent.customer
    user = User.find_by(stripe_customer_id: customer_id)
    if user
      user.update(subscription_status: 'inactive')
      user.reset_queries!
      NotificationMailer.payment_failed(user).deliver_later
      Rails.logger.info "Payment failed for user #{user.id}. Subscription status updated."
    else
      Rails.logger.warn "No user found with Stripe customer ID: #{customer_id}"
    end
  end

  def handle_subscription_schedule_completed(schedule)
    user = User.find_by(stripe_subscription_schedule_id: schedule.id)
    if user
      user.update(stripe_subscription_schedule_id: nil)
      Rails.logger.info "Subscription schedule completed for user #{user.id}. Resetting stripe_subscription_schedule_id."
    else
      Rails.logger.warn "No user found with Stripe subscription schedule ID: #{schedule.id}"
    end
  end
end
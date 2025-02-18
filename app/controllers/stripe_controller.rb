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
    when 'customer.subscription.updated'
      handle_subscription_updated(event.data.object)
    when 'customer.subscription.deleted'
      handle_subscription_deleted(event.data.object)
    when 'invoice.payment_succeeded'
      handle_invoice_payment_succeeded(event.data.object)
    when 'invoice.payment_failed'
      handle_invoice_payment_failed(event.data.object)
    when 'subscription_schedule.completed'
      handle_subscription_schedule_completed(event.data.object)
    when 'refund.created'
      handle_refund(event.data.object)
    when 'payment_method.attached'
      handle_payment_method_attached(event.data.object)
    else
      Rails.logger.info "Unhandled event type: #{event.type}"
    end

    render json: { status: 'success' }
  end

  private

  # Handle customer creation
  def handle_customer_created(customer)
    user = User.find_or_create_by(stripe_customer_id: customer.id)
    user.update!(email: customer.email)
    # Additional logic if needed
  end

  # Handle subscription changes
  def handle_subscription_created(subscription)
    user = User.find_by(stripe_customer_id: subscription.customer)
    user.update!(plan: subscription.items.data.first.price.id)
  end

  def handle_subscription_deleted(subscription)
    if user = User.find_by(stripe_customer_id: subscription.customer)
      user.update!(subscription_status: 'inactive')
    else
      Rails.logger.warn "No user found with Stripe customer ID: #{subscription.customer}"
    end
  end

  def handle_subscription_updated(subscription)
    user = User.find_by(stripe_customer_id: subscription.customer)
  
    if user
      new_plan_id = subscription.items.data.first&.price&.id
      if new_plan_id != user.plan
        Rails.logger.info "Subscription updated for user #{user.id}. New plan scheduled: #{new_plan_id}. Will apply on next billing cycle."
      end
      if subscription.metadata && subscription.metadata['new_queries_remaining']
        new_queries_remaining = subscription.metadata['new_queries_remaining'].to_i
        user.update!(queries_remaining: new_queries_remaining)
        Rails.logger.info "Updated query limit for user #{user.id} to #{new_queries_remaining} as per subscription metadata."
      end
      if subscription.metadata && subscription.metadata['change_status_to']
        new_status = subscription.metadata['change_status_to']
        user.update!(subscription_status: new_status)
        Rails.logger.info "Subscription status updated for user #{user.id} to #{new_status} as per subscription metadata."
      end
    else
      Rails.logger.warn "No user found with Stripe customer ID: #{subscription.customer}"
    end
  end

  # Handle successful payment
  def handle_invoice_payment_succeeded(invoice)
    customer_id = invoice.customer
    user = User.find_by(stripe_customer_id: customer_id)
    if user
      new_plan_id = invoice.lines.data.first&.price&.id
      if new_plan_id && new_plan_id != user.plan
        user.update!(plan: new_plan_id, subscription_status: 'active')
        Rails.logger.info "User #{user.id} upgraded/downgraded to new plan: #{new_plan_id}."
      else
        Rails.logger.info "Invoice payment succeeded for user #{user.id}, but no plan change detected."
      end
      user.reset_queries!
      # NotificationMailer.invoice_payment_succeeded(user).deliver_later
      Rails.logger.info "Reset queries for user #{user.id} due to successful payment. Subscription status set to active."
    else
      Rails.logger.warn "No user found with Stripe customer ID: #{customer_id}"
    end
  end

  def handle_invoice_payment_failed(invoice)
    customer_id = invoice.customer
    user = User.find_by(stripe_customer_id: customer_id)
    if user
      user.update(subscription_status: 'inactive')
      # NotificationMailer.invoice_payment_failed(user).deliver_later
      Rails.logger.info "Invoice payment failed for user #{user.id} with Stripe customer ID: #{customer_id}. Subscription status updated to inactive."
    else
      Rails.logger.warn "No user found with Stripe customer ID: #{customer_id}"
    end
  end

  def handle_subscription_schedule_completed(schedule)
    user = User.find_by(stripe_customer_id: schedule.customer)
    if user
      user.update!(stripe_subscription_schedule_id: nil)
      user.update!(subscription_status: 'active')
      Rails.logger.info "Subscription schedule completed for user #{user.id}. Resetting stripe_subscription_schedule_id to nil."
    else
      Rails.logger.warn "No user found with Stripe subscription schedule ID: #{schedule.id}"
    end
  end

  def handle_refund(refund)
    customer_id = refund.customer
    user = User.find_by(stripe_customer_id: customer_id)
    if user
      user.update!(subscription_status: 'inactive')
      # NotificationMailer.refund(user).deliver_later
      Rails.logger.info "Refunded user #{user.id} with Stripe customer ID: #{customer_id}. Subscription status updated to inactive."
    else
      Rails.logger.warn "No user found with Stripe customer ID: #{customer_id}"
    end
  end

  def handle_payment_method_attached(payment_method)
    customer_id = payment_method.customer
    user = User.find_by(stripe_customer_id: customer_id)
    if user
      user.update!(payment_method_id: payment_method.id)
      Rails.logger.info "Payment method attached for user #{user.id} with Stripe customer ID: #{customer_id}. Payment method ID set to #{payment_method.id}."
    else
      Rails.logger.warn "No user found with Stripe customer ID: #{customer_id}"
    end
  end
end
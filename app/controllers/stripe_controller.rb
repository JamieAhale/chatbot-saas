class StripeController < ApplicationController
  include ApplicationHelper
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
    when 'checkout.session.completed'
      handle_checkout_session_completed(event.data.object)
    when 'customer.subscription.updated'
      handle_subscription_updated(event.data.object)
    when 'customer.subscription.deleted'
      handle_subscription_deleted(event.data.object)
    when 'invoice.payment_succeeded'
      handle_invoice_payment_succeeded(event.data.object)
    when 'invoice.payment_failed'
      handle_invoice_payment_failed(event.data.object)
    when 'refund.created'
      handle_refund(event.data.object)
    else
      Rails.logger.info "Unhandled event type: #{event.type}"
    end

    render json: { status: 'success' }
  end

  private

  def handle_checkout_session_completed(session)
    user = User.find_by(stripe_customer_id: session.customer)
    if user
      user.update!(subscription_status: 'active')
      assistant_creator = PineconeAssistantCreator.new(user)
      unless assistant_creator.create
        Rails.logger.error "Error creating Pinecone assistant for user #{user.id}"
      end
    end
  end

  def handle_subscription_updated(subscription)
    user = User.find_by(stripe_customer_id: subscription.customer)
  
    if user
      new_plan_id = subscription.items.data.first&.price&.id
      if new_plan_id != user.plan
        Rails.logger.info "Subscription updated for user #{user.id}. New plan scheduled: #{new_plan_id}."
      end
      if subscription.metadata && subscription.metadata['new_queries_remaining']
        new_queries_remaining = subscription.metadata['new_queries_remaining'].to_i
        user.update!(queries_remaining: new_queries_remaining)
      end
      if subscription.metadata && subscription.metadata['change_status_to']
        new_status = subscription.metadata['change_status_to']
        user.update!(subscription_status: new_status)
      end
    else
      Rails.logger.warn "No user found with Stripe customer ID: #{subscription.customer}"
    end
  end

  def handle_subscription_deleted(subscription)
    if user = User.find_by(stripe_customer_id: subscription.customer)
      user.update!(subscription_status: 'inactive')
    else
      Rails.logger.warn "No user found with Stripe customer ID: #{subscription.customer}"
    end
  end

  # Handle successful payment
  def handle_invoice_payment_succeeded(invoice)
    customer_id = invoice.customer
    user = User.find_by(stripe_customer_id: customer_id)
    if user
      plan_line_items = invoice.lines.data.select { |line| line.plan.present? }
      plan_id = plan_line_items.last&.plan&.id
      user.update!(plan: plan_id, subscription_status: 'active')
      user.reset_queries!
      NotificationMailer.invoice_payment_succeeded(user).deliver_later
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
      NotificationMailer.invoice_payment_failed(user).deliver_later
      Rails.logger.info "Invoice payment failed for user #{user.id} with Stripe customer ID: #{customer_id}. Subscription status updated to inactive."
    else
      Rails.logger.warn "No user found with Stripe customer ID: #{customer_id}"
    end
  end

  def handle_refund(refund)
    customer_id = refund.customer
    user = User.find_by(stripe_customer_id: customer_id)
    if user
      user.update!(subscription_status: 'inactive')
      NotificationMailer.refund(user).deliver_later
      Rails.logger.info "Refunded user #{user.id} with Stripe customer ID: #{customer_id}. Subscription status updated to inactive."
    else
      Rails.logger.warn "No user found with Stripe customer ID: #{customer_id}"
    end
  end
end
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable

  before_create :assign_uuid

  has_many :conversations

  # Define the maximum number of queries for each plan
  PLAN_QUERY_LIMITS = {
    'Lite' => 500,
    'Basic' => 2000,
    'Pro' => 10000
  }.freeze

  # Returns the query limit based on the user's current plan
  def query_limit
    PLAN_QUERY_LIMITS[plan_name] || 0
  end

  # Resets the user's remaining queries based on their plan
  def reset_queries!
    update!(queries_remaining: query_limit)
  end

  # Decrements the remaining queries by 1
  def decrement_queries!
    update!(queries_remaining: queries_remaining - 1)
  end

  # Checks if the user has remaining queries
  def can_make_query?
    queries_remaining.present? && queries_remaining > 0 && subscription_status == 'active'
  end

  # Create a Stripe customer and subscribe to a plan
  def create_stripe_customer(token, price_id)
    customer = Stripe::Customer.create(
      email: email,
      source: token
    )
    update(
      stripe_customer_id: customer.id,
      subscription_status: 'active'
    )
    subscribe_to_plan(price_id)
  rescue Stripe::StripeError => e
    Rails.logger.error "Stripe Error in create_stripe_customer: #{e.message}"
    errors.add(:base, "There was an issue creating your account: #{e.message}")
    false
  end

  # Subscribe the Stripe customer to a plan
  def subscribe_to_plan(price_id)
    subscription = Stripe::Subscription.create(
      customer: stripe_customer_id,
      items: [{ price: price_id }],
      expand: ['latest_invoice.payment_intent']
    )
    update(
      stripe_subscription_id: subscription.id,
      plan: price_id,
      subscription_status: subscription.status
    )
    reset_queries!
  rescue Stripe::StripeError => e
    Rails.logger.error "Stripe Error in subscribe_to_plan: #{e.message}"
    errors.add(:base, "There was an issue subscribing to the plan: #{e.message}")
    false
  end

  # Change the subscription plan
  def change_plan(new_price_id)
    return false unless stripe_subscription_id.present?

    subscription = Stripe::Subscription.retrieve(stripe_subscription_id)
    updated_subscription = Stripe::Subscription.update(
      stripe_subscription_id,
      {
        cancel_at_period_end: false,
        proration_behavior: 'always_invoice',
        items: [{
          id: subscription.items.data[0].id,
          price: new_price_id
        }]
      }
    )
    
    if updated_subscription.latest_invoice
      invoice = Stripe::Invoice.retrieve(updated_subscription.latest_invoice)
      Stripe::Invoice.pay(invoice.id) if invoice.status == 'open'
    end
    
    update(plan: new_price_id, subscription_status: updated_subscription.status)
    reset_queries!
    true
  rescue Stripe::StripeError => e
    Rails.logger.error "Stripe Error in change_plan: #{e.message}"
    false
  end

  # Cancel the subscription
  def cancel_subscription
    return false unless stripe_subscription_id.present?

    subscription = Stripe::Subscription.retrieve(stripe_subscription_id)
    canceled_subscription = Stripe::Subscription.update(
      stripe_subscription_id,
      { cancel_at_period_end: true }
    )
    update(subscription_status: canceled_subscription.status)
    true
  rescue Stripe::StripeError => e
    Rails.logger.error "Stripe Error in cancel_subscription: #{e.message}"
    false
  end

  # Resume the subscription
  def resume_subscription
    return false unless stripe_subscription_id.present?

    subscription = Stripe::Subscription.retrieve(stripe_subscription_id)
    resumed_subscription = Stripe::Subscription.update(
      stripe_subscription_id,
      { cancel_at_period_end: false }
    )
    update(subscription_status: resumed_subscription.status)
    true
  rescue Stripe::StripeError => e
    Rails.logger.error "Stripe Error in resume_subscription: #{e.message}"
    false
  end

  # Get the plan name based on the price ID
  def plan_name
    case plan
    when ENV['STRIPE_PRICE_LITE_ID']
      'Lite'
    when ENV['STRIPE_PRICE_BASIC_ID']
      'Basic'
    when ENV['STRIPE_PRICE_PRO_ID']
      'Pro'
    else
      'No Plan'
    end
  end

  # Retrieve the Stripe subscription object
  def subscription
    Stripe::Subscription.retrieve(stripe_subscription_id)
  end

  # Compute the assistant name using the user's id
  def pinecone_assistant_name
    "assistant-#{id}"
  end

  private

  def assign_uuid
    self.id = SecureRandom.uuid if id.blank?
  end
end

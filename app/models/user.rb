class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable

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
        items: [{
          id: subscription.items.data[0].id,
          price: new_price_id
        }]
      }
    )
    update(plan: new_price_id, subscription_status: updated_subscription.status)
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
end

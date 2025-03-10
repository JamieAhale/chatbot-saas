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

  # Create a Stripe customer without immediately subscribing to a plan
  def create_stripe_customer_only
    customer = Stripe::Customer.create(email: self.email)
    update(stripe_customer_id: customer.id, subscription_status: 'incomplete')
  rescue Stripe::StripeError => e
    Rails.logger.error "Stripe Error in create_stripe_customer_only: #{e.message}"
    errors.add(:base, "There was an issue creating your Stripe customer: #{e.message}")
    false
  end

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

  def pinecone_assistant_name
    "assistant-#{id}"
  end

  private

  def assign_uuid
    self.id = SecureRandom.uuid if id.blank?
  end
end

class SubscriptionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user

  # GET /subscription/edit
  def edit
    @plans = {
      'Lite' => ENV['STRIPE_PRICE_LITE_ID'],
      'Basic' => ENV['STRIPE_PRICE_BASIC_ID'],
      'Pro' => ENV['STRIPE_PRICE_PRO_ID']
    }
    @subscription = @user.subscription
    timestamp = @subscription.current_period_end
    @current_period_end = Time.at(timestamp).utc.strftime("%B %d, %Y")

    schedule = Stripe::SubscriptionSchedule.retrieve(@user.stripe_subscription_schedule_id) rescue nil
      
    if schedule && schedule.phases.count > 1
      downgrade_phase = schedule.phases[1]
      if downgrade_phase.start_date > Time.current.to_i
        @scheduled_downgrade_price_id = downgrade_phase.items.first.price
        @scheduled_downgrade_date = Time.at(downgrade_phase.start_date).utc.strftime("%B %d, %Y")
        @already_changed_plan = true and return
      end
    end

    # Example logic for upgrades:
    # (You'll need to devise logic to record when an upgrade was performed.
    # For example, if you track last_plan_change_at on your subscription or user,
    # you could do something like:)
    # @already_changed_plan = @subscription.last_plan_change_at &&
    #                         (Time.at(@subscription.current_period_start) < @subscription.last_plan_change_at)
    #
    # For now, if you only use scheduled downgrades to represent a change, you might simply assume:
    @already_changed_plan = false
  end

  # PATCH/PUT /subscription
  def update
    new_price_id = subscription_params[:price_id]
    current_subscription = Stripe::Subscription.retrieve(@user.stripe_subscription_id)
    current_period_start = current_subscription.current_period_start
    current_period_end   = current_subscription.current_period_end

    if downgrade?(current_price_id: current_subscription.items.data[0].price.id, new_price_id: new_price_id)
      begin
        # Retrieve the schedule directly if the ID is stored, otherwise create a new schedule.
        schedule = if @user.stripe_subscription_schedule_id.present?
                     Stripe::SubscriptionSchedule.retrieve(@user.stripe_subscription_schedule_id)
                   else
                     new_schedule = Stripe::SubscriptionSchedule.create({
                       from_subscription: @user.stripe_subscription_id
                     })
                     # Store the new schedule's ID in the user's record.
                     @user.update(stripe_subscription_schedule_id: new_schedule.id)
                     new_schedule
                   end

        # Update the schedule with two phases:
        # Phase 1: Continue the current plan until current_period_end.
        # Phase 2: Downgrade to the new plan starting at current_period_end.
        updated_schedule = Stripe::SubscriptionSchedule.update(schedule.id, {
          phases: [
            {
              start_date: current_period_start,
              end_date: current_period_end,
              items: [{
                price: current_subscription.items.data[0].price.id
              }]
            },
            {
              start_date: current_period_end,
              items: [{
                price: new_price_id
              }]
            }
          ]
        })

        flash[:success] = "Your downgrade to #{plan_name_from_price_id(new_price_id)} has been scheduled to take effect on #{Time.at(current_period_end).utc.strftime('%B %d, %Y')}."
        redirect_to user_show_path
      rescue Stripe::StripeError => e
        Rails.logger.error "Stripe Error scheduling downgrade: #{e.message}"
        flash[:error] = "Failed to schedule your downgrade. Please try again later."
        redirect_to edit_subscription_path
      end
    else
      # If it's an upgrade or another change, proceed immediately.
      if @user.change_plan(new_price_id)
        flash[:success] = 'Plan updated successfully.'
        redirect_to user_show_path
      else
        flash[:error] = 'Failed to update your plan.'
        redirect_to edit_subscription_path
      end
    end
  end

  # DELETE /subscription
  def destroy
    if @user.cancel_subscription
      flash[:success] = 'Your subscription will be canceled at the end of the current billing cycle.'
      redirect_to user_show_path
    else
      flash[:error] = 'Failed to cancel your subscription.'
      redirect_to user_show_path
    end
  end

  def resume
    if @user.resume_subscription
      flash[:success] = 'Your subscription has been resumed.'
      redirect_to user_show_path
    else
      flash[:error] = 'Failed to resume your subscription.'
      redirect_to user_show_path
    end
  end

  def payment_details
    @stripe_public_key = ENV['STRIPE_PUBLIC_KEY']
    @setup_intent = Stripe::SetupIntent.create(
      customer: @user.stripe_customer_id,
      payment_method_types: ['card']
    )
    
    # Fetch current payment method
    payment_methods = Stripe::PaymentMethod.list({
      customer: @user.stripe_customer_id,
      type: 'card'
    })
    
    if payment_methods.data.any?
      @current_card = payment_methods.data.first
    end
  end

  def update_payment_method
    setup_intent = Stripe::SetupIntent.retrieve(params[:setup_intent_id])
    payment_method = setup_intent.payment_method
    
    # Attach the payment method to the customer
    Stripe::PaymentMethod.attach(payment_method, { customer: @user.stripe_customer_id })
    
    # Set it as the default payment method
    Stripe::Customer.update(
      @user.stripe_customer_id,
      { invoice_settings: { default_payment_method: payment_method } }
    )

    flash[:success] = "Payment method updated successfully."
    redirect_to user_show_path
  rescue Stripe::StripeError => e
    flash[:error] = "Error updating payment method: #{e.message}"
    redirect_to payment_details_path
  end

  private

  def set_user
    @user = current_user
  end

  def subscription_params
    params.require(:subscription).permit(:price_id)
  end

  # Example helper to determine if this is a downgrade.
  def downgrade?(current_price_id:, new_price_id:)
    # For example, compare query limits or a defined hierarchy.
    # You might have a hash like:
    # { ENV['STRIPE_PRICE_PRO_ID'] => 499, ENV['STRIPE_PRICE_BASIC_ID'] => 249, ENV['STRIPE_PRICE_LITE_ID'] => 99 }
    current_limit = User::PLAN_QUERY_LIMITS[plan_name_from_price_id(current_price_id)]
    new_limit     = User::PLAN_QUERY_LIMITS[plan_name_from_price_id(new_price_id)]
    new_limit < current_limit
  end

  def plan_name_from_price_id(price_id)
    case price_id
    when ENV['STRIPE_PRICE_LITE_ID']
      'Lite'
    when ENV['STRIPE_PRICE_BASIC_ID']
      'Basic'
    when ENV['STRIPE_PRICE_PRO_ID']
      'Pro'
    else
      'Unknown Plan'
    end
  end
end

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
  end

  # PATCH/PUT /subscription
  def update
    new_price_id = subscription_params[:price_id]
    if @user.change_plan(new_price_id)
      respond_to do |format|
        format.html { 
          flash[:success] = 'Plan updated successfully.'
          redirect_to user_show_path 
        }
        format.any { head :ok }
      end
    else
      respond_to do |format|
        format.html do
          flash[:error] = 'Failed to update your plan.'
          redirect_to edit_subscription_path
        end
        format.any { head :unprocessable_entity }
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
end

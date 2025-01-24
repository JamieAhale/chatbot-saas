class SubscriptionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user

  # GET /subscription/edit
  def edit
    @plans = {
      'Basic' => ENV['STRIPE_PRICE_BASIC_ID'],
      'Pro' => ENV['STRIPE_PRICE_PRO_ID'],
      'Enterprise' => ENV['STRIPE_PRICE_ENTERPRISE_ID']
    }
  end

  # PATCH/PUT /subscription
  def update
    raise "@user: #{@user.inspect}"
    new_price_id = subscription_params[:price_id]
    if @user.change_plan(new_price_id)
      redirect_to user_show_path, notice: 'Your plan has been updated successfully.'
    else
      flash[:alert] = 'Failed to update your plan.'
      redirect_to edit_subscription_path
    end
  end

  # DELETE /subscription
  def destroy
    if @user.cancel_subscription
      redirect_to user_show_path, notice: 'Your subscription will be canceled at the end of the current billing cycle.'
    else
      redirect_to user_show_path, alert: 'Failed to cancel your subscription.'
    end
  end

  private

  def set_user
    @user = current_user
  end

  def subscription_params
    params.require(:subscription).permit(:price_id)
  end
end

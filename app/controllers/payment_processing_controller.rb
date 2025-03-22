class PaymentProcessingController < ApplicationController
  before_action :authenticate_user!

  def show
    render :show
  end

  def status
    if current_user.subscription_status == 'active'
      render json: { active: true }
    else
      render json: { active: false }
    end
  end
end 
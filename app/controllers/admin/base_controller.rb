class Admin::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_super_admin!

  private

  def ensure_super_admin!
    unless current_user&.super_admin?
      flash[:alert] = "Access denied. This area is restricted to super administrators."
      redirect_to root_path
    end
  end
end

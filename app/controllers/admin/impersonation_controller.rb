class Admin::ImpersonationController < Admin::BaseController
  def start
    user = User.find_by(id: params[:id])
    
    unless user
      flash[:alert] = "User not found."
      redirect_to admin_dashboard_path and return
    end
    
    unless user.can_be_impersonated_by?(true_current_user)
      flash[:alert] = "This user cannot be impersonated."
      redirect_to admin_dashboard_path and return
    end
    
    session[:impersonate_user_id] = user.id
    Rails.logger.info "Admin #{true_current_user.email} started impersonating #{user.email} (IP: #{request.remote_ip})"
    redirect_to root_path, notice: "Now impersonating #{user.email}"
  end

  def stop
    impersonated_user_email = current_user&.email
    session.delete(:impersonate_user_id)
    Rails.logger.info "Admin #{true_current_user.email} stopped impersonating #{impersonated_user_email} (IP: #{request.remote_ip})"
    redirect_to admin_dashboard_path, notice: "Stopped impersonation"
  end

  private

  def ensure_super_admin!
    unless true_current_user&.super_admin?
      Rails.logger.warn "Unauthorized impersonation attempt by user #{true_current_user&.id} (IP: #{request.remote_ip})"
      flash[:alert] = "Access denied. This area is restricted to super administrators."
      redirect_to root_path
    end
  end
end
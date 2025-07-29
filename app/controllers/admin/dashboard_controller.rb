class Admin::DashboardController < Admin::BaseController
  def index
    @users = User.all.includes(:conversations)
    
    if params[:search].present?
      @users = @users.where("email ILIKE ?", "%#{params[:search]}%")
    end
    
    @users = @users.order(:created_at)
                   .page(params[:page])
                   .per(20)
    
    @total_users = User.count
    @active_subscriptions = User.where(subscription_status: 'active').count
    @total_conversations = Conversation.count
  end
end

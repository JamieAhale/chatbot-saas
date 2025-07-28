class Admin::DashboardController < Admin::BaseController
  def index
    @users = User.all.includes(:conversations)
                   .order(:created_at)
                   .page(params[:page])
                   .per(20)
    
    @total_users = User.count
    @active_subscriptions = User.where(subscription_status: 'active').count
    @total_conversations = Conversation.count
  end
end

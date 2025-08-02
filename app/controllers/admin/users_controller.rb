class Admin::UsersController < Admin::BaseController
  def show
    @user = User.find(params[:id])
    @conversations = @user.conversations.order(created_at: :desc).limit(10)
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    
    user_creator = AdminUserCreator.new(user_params)
    
    if user_creator.create
      flash[:success] = "User created successfully! The user has been set up with Stripe customer, Pinecone assistant, and an email with login credentials has been sent to #{user_creator.user.email}"
      redirect_to admin_dashboard_path
    else
      # Set @user for form re-rendering
      @user = user_creator.user || User.new(user_params)
      flash.now[:alert] = user_creator.errors.join(', ')
      render :new
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :first_name, :last_name, :role, :plan, :subscription_status, :queries_remaining)
  end
end

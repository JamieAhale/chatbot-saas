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
      flash[:success] = "User created successfully! The user has been set up with Stripe customer, Pinecone assistant, and an admin notification has been sent to you with their credentials."
      redirect_to admin_dashboard_path
    else
      # Set @user for form re-rendering
      @user = user_creator.user || User.new(user_params)
      flash.now[:alert] = user_creator.errors.join(', ')
      render :new
    end
  end

  def send_login_info
    @user = User.find(params[:id])
    temp_password = SecureRandom.hex(8)
    
    # Update user's password
    @user.update!(
      password: temp_password,
      password_confirmation: temp_password
    )
    
    # Send login info to user
    NotificationMailer.send_user_login_info(@user, temp_password).deliver_now
    
    # Send confirmation to admin
    NotificationMailer.login_info_sent_confirmation(@user, temp_password).deliver_now
    
    flash[:success] = "Login credentials have been sent to #{@user.email} and a confirmation email has been sent to you."
    redirect_to admin_user_path(@user)
  rescue => e
    flash[:alert] = "Failed to send login info: #{e.message}"
    redirect_to admin_user_path(@user)
  end

  private

  def user_params
    params.require(:user).permit(:email, :first_name, :last_name, :role, :plan, :subscription_status, :queries_remaining)
  end
end

class ExpireBetaUserJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    
    # Only expire if user is still on beta plan (hasn't upgraded)
    if user.plan == 'beta_user'
      user.update!(subscription_status: 'incomplete')
      NotificationMailer.beta_trial_expired(user).deliver_now
      Rollbar.info("Expired beta trial for user #{user_id}")
    else
      Rollbar.info("Skipped beta expiration for user #{user_id} - already upgraded to #{user.plan_name}")
    end
  rescue ActiveRecord::RecordNotFound
    Rollbar.warning("ExpireBetaUserJob: User #{user_id} not found")
  end
end 
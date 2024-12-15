class AddEmailNotificationsEnabledToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :email_notifications_enabled, :boolean
  end
end

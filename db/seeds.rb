# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Create super admin user
super_admin = User.find_or_initialize_by(email: 'jamie@bravik.com.au')

# Set attributes whether user is new or existing
super_admin.assign_attributes(
  password: "temppassword123",
  password_confirmation: "temppassword123",
  first_name: 'Jamie',
  last_name: 'Ahale',
  role: 'super_admin',
  subscription_status: 'active',
  queries_remaining: 1000000,
  confirmed_at: Time.current
)

if super_admin.save
  puts "Super admin user created/updated: #{super_admin.email}"
else
  puts "Failed to create super admin user: #{super_admin.errors.full_messages.join(', ')}"
end

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Load exercise seeds
load Rails.root.join("db/seeds/exercises.rb")

# Create admin user
# admin = User.find_or_initialize_by(email_address: 'admin@haearn.com')
# if admin.new_record?
#   admin.update!(
#     name: 'Admin',
#     password: 'password',
#     password_confirmation: 'password',
#     admin: true,
#     preferred_unit: 'kg'
#   )
#   puts "Admin user created: admin@haearn.com"
# else
#   admin.update!(admin: true) unless admin.admin?
#   puts "Admin user already exists: admin@haearn.com"
# end

puts "Seeding complete!"

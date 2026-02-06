# == Schema Information
#
# Table name: gyms
#
#  id         :integer          not null, primary key
#  location   :string
#  name       :string
#  notes      :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :integer          not null
#
# Indexes
#
#  index_gyms_on_user_id  (user_id)
#
# Foreign Keys
#
#  user_id  (user_id => users.id)
#
# Represents a physical gym location where the user trains
# 
# Features:
# - Each gym can have multiple machines/equipment with specific configurations
# - Tracks location (address/area) and notes for the gym
# - When deleted, machines are destroyed but workouts keep the gym_id (nullified)
# - User can set a default gym for quick workout creation
# 
# Why track gyms?
# - Same exercise on different machines feels different (important for PRs)
# - Different gyms have different equipment (cable ratios, plate increments)
# - Allows filtering workout history by location
class Gym < ApplicationRecord
  belongs_to :user
  has_many :machines, dependent: :destroy
  has_many :workouts, dependent: :nullify  # Keep workout history even if gym deleted

  validates :name, presence: true

  scope :ordered, -> { order(:name) }
end

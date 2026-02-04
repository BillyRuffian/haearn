# == Schema Information
#
# Table name: users
#
#  id                   :integer          not null, primary key
#  default_rest_seconds :integer          default(90)
#  email_address        :string           not null
#  name                 :string
#  password_digest      :string           not null
#  preferred_unit       :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  default_gym_id       :integer
#
# Indexes
#
#  index_users_on_default_gym_id  (default_gym_id)
#  index_users_on_email_address   (email_address) UNIQUE
#
# Foreign Keys
#
#  default_gym_id  (default_gym_id => gyms.id)
#
class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :gyms, dependent: :destroy
  has_many :exercises, dependent: :destroy
  has_many :workouts, dependent: :destroy
  belongs_to :default_gym, class_name: 'Gym', optional: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # Validations
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :preferred_unit, inclusion: { in: %w[kg lbs], allow_nil: true }
  validates :default_rest_seconds, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 30,
    less_than_or_equal_to: 300,
    allow_nil: true
  }

  # Units
  UNITS = %w[kg lbs].freeze

  # Rest timer bounds
  MIN_REST_SECONDS = 30
  MAX_REST_SECONDS = 300
  DEFAULT_REST_SECONDS = 90

  def preferred_unit
    super || 'kg'
  end

  def default_rest_seconds
    super || DEFAULT_REST_SECONDS
  end

  # Convert weight from kg to user's preferred unit for display
  def display_weight(kg_value)
    return nil if kg_value.nil?

    if preferred_unit == 'lbs'
      (kg_value * 2.20462).round(1)
    else
      kg_value.round(1)
    end
  end

  # Convert weight from user's input unit to kg for storage
  def normalize_weight(value)
    return nil if value.nil?

    if preferred_unit == 'lbs'
      (value / 2.20462).round(2)
    else
      value.to_f.round(2)
    end
  end

  # Alias for normalize_weight
  alias_method :to_kg, :normalize_weight

  # Get available exercises (global + user's custom)
  def available_exercises
    Exercise.for_user(self).ordered
  end

  # Current active workout
  def active_workout
    workouts.in_progress.first
  end
end

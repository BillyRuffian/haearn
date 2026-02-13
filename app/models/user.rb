# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
#  admin                  :boolean          default(FALSE), not null
#  deactivated_at         :datetime
#  default_rest_seconds   :integer          default(90)
#  email_address          :string           not null
#  name                   :string
#  password_digest        :string           not null
#  preferred_unit         :string
#  progression_rep_target :integer          default(10), not null
#  weekly_summary_email   :boolean          default(FALSE), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  default_gym_id         :integer
#
# Indexes
#
#  index_users_on_admin           (admin)
#  index_users_on_default_gym_id  (default_gym_id)
#  index_users_on_email_address   (email_address) UNIQUE
#
# Foreign Keys
#
#  default_gym_id  (default_gym_id => gyms.id)
#
# Weight Handling:
# - All weights stored in kg in database (normalized)
# - display_weight() converts to user's preferred unit for display
# - normalize_weight() converts user input back to kg for storage
class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :gyms, dependent: :destroy
  has_many :exercises, dependent: :destroy  # custom exercises only
  has_many :workouts, dependent: :destroy
  has_many :workout_blocks, through: :workouts
  has_many :workout_exercises, through: :workout_blocks
  has_many :exercise_sets, through: :workout_exercises
  has_many :workout_templates, dependent: :destroy
  has_many :body_metrics, dependent: :destroy
  has_many :progress_photos, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :admin_audit_logs, foreign_key: :admin_user_id, dependent: :nullify, inverse_of: :admin_user
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
  validates :progression_rep_target, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 5,
    less_than_or_equal_to: 20
  }

  # Scopes
  scope :active, -> { where(deactivated_at: nil) }
  scope :deactivated, -> { where.not(deactivated_at: nil) }
  scope :admins, -> { where(admin: true) }

  # Supported weight units
  UNITS = %w[kg lbs].freeze

  # Rest timer configuration (prevents too short or absurdly long rest periods)
  MIN_REST_SECONDS = 30   # 30 seconds minimum
  MAX_REST_SECONDS = 300  # 5 minutes maximum
  DEFAULT_REST_SECONDS = 90  # 90 seconds default (good for most exercises)

  # Progression readiness rep target (determines when user is ready to progress)
  MIN_PROGRESSION_REP_TARGET = 5
  MAX_PROGRESSION_REP_TARGET = 20
  DEFAULT_PROGRESSION_REP_TARGET = 10

  # Always return a unit, default to kg if not set
  def preferred_unit
    super || 'kg'
  end

  # Always return a rest time, default to 90 seconds if not set
  def default_rest_seconds
    super || DEFAULT_REST_SECONDS
  end

  # Convert weight from kg (database storage) to user's preferred unit for display
  # @param kg_value [Numeric] weight in kilograms
  # @return [Float] weight in user's preferred unit (rounded to 2 d.p.)
  def display_weight(kg_value)
    return nil if kg_value.nil?

    if preferred_unit == 'lbs'
      (kg_value * 2.20462).round(2)  # 1 kg = 2.20462 lbs
    else
      kg_value.round(2)
    end
  end

  # Format weight for display, showing decimals only when not a whole number
  # @param kg_value [Numeric] weight in kilograms
  # @return [String] formatted weight (e.g., "100" or "100.5" or "100.25")
  def format_weight(kg_value)
    value = display_weight(kg_value)
    return nil if value.nil?

    if value == value.to_i
      value.to_i.to_s
    elsif value == value.round(1)
      format('%.1f', value)
    else
      format('%.2f', value)
    end
  end

  # Convert weight from user's input unit to kg for database storage
  # @param value [Numeric] weight in user's preferred unit
  # @return [Float] weight in kilograms
  def normalize_weight(value)
    return nil if value.nil?

    if preferred_unit == 'lbs'
      (value / 2.20462).round(2)  # Convert lbs to kg
    else
      value.to_f.round(2)
    end
  end

  # Alias for normalize_weight (more intuitive name for conversion)
  alias_method :to_kg, :normalize_weight

  def admin?
    admin
  end

  def deactivated?
    deactivated_at.present?
  end

  def active?
    !deactivated?
  end

  # Get all available exercises for this user (global seeded + user's custom)
  # @return [ActiveRecord::Relation<Exercise>]
  def available_exercises
    Exercise.for_user(self).ordered
  end

  # Get the user's currently in-progress workout (if any)
  # @return [Workout, nil]
  def active_workout
    workouts.in_progress.first
  end
end

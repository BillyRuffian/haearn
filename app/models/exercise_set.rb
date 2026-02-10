# == Schema Information
#
# Table name: exercise_sets
#
#  id                  :integer          not null, primary key
#  completed_at        :datetime
#  distance_meters     :decimal(, )
#  duration_seconds    :integer
#  is_warmup           :boolean
#  position            :integer
#  reps                :integer
#  rir                 :integer
#  rpe                 :decimal(, )
#  weight_kg           :decimal(, )
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  workout_exercise_id :integer          not null
#
# Indexes
#
#  index_exercise_sets_on_workout_exercise_id  (workout_exercise_id)
#
# Foreign Keys
#
#  workout_exercise_id  (workout_exercise_id => workout_exercises.id)
#
# Logging Flow:
# User input → WeightConverter (handles unit + ratio) → kg → Database
# Database → User's unit preference → Display
class ExerciseSet < ApplicationRecord
  belongs_to :workout_exercise

  has_one :workout_block, through: :workout_exercise
  has_one :workout, through: :workout_block
  has_one :exercise, through: :workout_exercise

  validates :position, presence: true, numericality: { greater_than: 0 }
  validates :weight_kg, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :reps, numericality: { greater_than: 0, only_integer: true }, allow_nil: true
  validates :duration_seconds, numericality: { greater_than: 0, only_integer: true }, allow_nil: true
  validates :distance_meters, numericality: { greater_than: 0 }, allow_nil: true
  validates :rpe, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 10 }, allow_nil: true
  validates :rir, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10, only_integer: true }, allow_nil: true

  scope :ordered, -> { order(:position) }
  scope :warmup, -> { where(is_warmup: true) }
  scope :working, -> { where(is_warmup: false) }  # "Working sets" = not warmup
  scope :completed, -> { where.not(completed_at: nil) }

  before_validation :set_position, on: :create

  # Set type checks
  def warmup?
    is_warmup == true
  end

  def working?
    !warmup?
  end

  def completed?
    completed_at.present?
  end

  # Mark set as completed with timestamp
  def complete!
    update!(completed_at: Time.current)
  end

  # Calculate training volume for this set (weight × reps)
  # Used for volume statistics and tracking
  # @return [Numeric] volume in kg
  def volume_kg
    return 0 unless weight_kg && reps
    weight_kg * reps
  end

  # Check if this set achieved a weight PR
  # (highest weight ever lifted for this exercise+machine combo)
  # @return [Boolean]
  def weight_pr?
    PrCalculator.weight_pr?(self)
  end

  private

  # Auto-assign position as last set for this exercise when created
  def set_position
    return if position.present?
    max_position = workout_exercise.exercise_sets.maximum(:position) || 0
    self.position = max_position + 1
  end
end

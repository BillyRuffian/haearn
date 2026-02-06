# == Schema Information
#
# Table name: workout_exercises
#
#  id               :integer          not null, primary key
#  persistent_notes :text
#  position         :integer
#  session_notes    :text
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  exercise_id      :integer          not null
#  machine_id       :integer          not null
#  workout_block_id :integer          not null
#
# Indexes
#
#  index_workout_exercises_on_exercise_id       (exercise_id)
#  index_workout_exercises_on_machine_id        (machine_id)
#  index_workout_exercises_on_workout_block_id  (workout_block_id)
#
# Foreign Keys
#
#  exercise_id       (exercise_id => exercises.id)
#  machine_id        (machine_id => machines.id)
#  workout_block_id  (workout_block_id => workout_blocks.id)
#
# Represents a specific exercise within a workout block
# 
# The bridge between abstract exercises and actual workout performance
# Tracks which exercise, which machine, and which position in the block
# 
# Two Types of Notes:
# 1. session_notes: Temporary notes specific to this workout
#    Example: "Shoulder felt off on set 3, stopped early"
# 2. persistent_notes: Carried forward to future workouts
#    Example: "Use neutral grip handle, seat at position 4"
# 
# Why separate notes?
# - Session notes are logged once, help with injury tracking
# - Persistent notes automatically copy to next workout for setup reminders
class WorkoutExercise < ApplicationRecord
  belongs_to :workout_block
  belongs_to :exercise
  belongs_to :machine
  has_many :exercise_sets, -> { order(:position) }, dependent: :destroy

  has_one :workout, through: :workout_block

  validates :position, presence: true, numericality: { greater_than: 0 }

  scope :ordered, -> { order(:position) }

  before_validation :set_position, on: :create

  # Delegate methods to related models for convenience
  delegate :name, to: :exercise, prefix: true
  delegate :exercise_type, :has_weight, :reps?, :time?, :distance?, to: :exercise

  # Get only working sets (exclude warmups)
  def working_sets
    exercise_sets.where(is_warmup: false)
  end

  # Get only warmup sets
  def warmup_sets
    exercise_sets.where(is_warmup: true)
  end

  # Find the last time this exact exercise+machine combo was performed
  # Used to display previous performance during workout ("Last time: 3×225lbs")
  # Only considers finished workouts from same user
  def previous_workout_exercise
    WorkoutExercise
      .joins(:workout_block)
      .joins('INNER JOIN workouts ON workouts.id = workout_blocks.workout_id')
      .where(exercise_id: exercise_id)
      .where(machine_id: machine_id)
      .where('workouts.user_id = ?', workout.user_id)
      .where('workouts.id != ?', workout.id)
      .where('workouts.finished_at IS NOT NULL')
      .order('workouts.started_at DESC')
      .first
  end

  # Alias for view compatibility
  alias_method :previous_exercise, :previous_workout_exercise

  # Check if this session achieved a volume PR (weight × reps)
  # @return [Boolean]
  def volume_pr?
    PrCalculator.volume_pr?(self)
  end

  # Get the best weight ever lifted for this exercise+machine combo
  # Used for showing PR indicators
  # @return [Numeric, nil]
  def previous_best_weight
    @previous_best_weight ||= PrCalculator.previous_best_weight(self)
  end

  private

  # Auto-assign position within the block when created
  # For supersets: position determines order (A1, A2, A3)
  def set_position
    return if position.present?
    max_position = workout_block.workout_exercises.maximum(:position) || 0
    self.position = max_position + 1
  end
end

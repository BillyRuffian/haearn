class WorkoutExercise < ApplicationRecord
  belongs_to :workout_block
  belongs_to :exercise
  belongs_to :machine
  has_many :exercise_sets, -> { order(:position) }, dependent: :destroy

  has_one :workout, through: :workout_block

  validates :position, presence: true, numericality: { greater_than: 0 }

  scope :ordered, -> { order(:position) }

  before_validation :set_position, on: :create

  delegate :name, to: :exercise, prefix: true
  delegate :exercise_type, :has_weight, :reps?, :time?, :distance?, to: :exercise

  def working_sets
    exercise_sets.where(is_warmup: false)
  end

  def warmup_sets
    exercise_sets.where(is_warmup: true)
  end

  # Get the last time this exercise was performed (for showing previous weights)
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

  private

  def set_position
    return if position.present?
    max_position = workout_block.workout_exercises.maximum(:position) || 0
    self.position = max_position + 1
  end
end

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

  # Check if this session's volume is a PR for this exercise+machine combo
  def volume_pr?
    PrCalculator.volume_pr?(self)
  end

  # Get the previous best weight for this exercise+machine combo
  def previous_best_weight
    @previous_best_weight ||= PrCalculator.previous_best_weight(self)
  end

  private

  def set_position
    return if position.present?
    max_position = workout_block.workout_exercises.maximum(:position) || 0
    self.position = max_position + 1
  end
end

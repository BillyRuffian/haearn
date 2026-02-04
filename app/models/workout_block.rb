class WorkoutBlock < ApplicationRecord
  belongs_to :workout
  has_many :workout_exercises, -> { order(:position) }, dependent: :destroy
  has_many :exercises, through: :workout_exercises
  has_many :exercise_sets, through: :workout_exercises

  validates :position, presence: true, numericality: { greater_than: 0 }

  scope :ordered, -> { order(:position) }

  before_validation :set_position, on: :create
  before_validation :set_default_rest_seconds, on: :create

  def superset?
    workout_exercises.count > 1
  end

  def single_exercise?
    workout_exercises.count == 1
  end

  # Default rest time (in seconds) - can be overridden
  def rest_seconds
    super || workout&.user&.default_rest_seconds || User::DEFAULT_REST_SECONDS
  end

  private

  def set_position
    return if position.present?
    max_position = workout.workout_blocks.maximum(:position) || 0
    self.position = max_position + 1
  end

  def set_default_rest_seconds
    return if self[:rest_seconds].present?
    self.rest_seconds = workout&.user&.default_rest_seconds
  end
end

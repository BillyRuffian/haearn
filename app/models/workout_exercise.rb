# == Schema Information
#
# Table name: workout_exercises
#
#  id               :integer          not null, primary key
#  bar_type         :string
#  grip_width       :string
#  incline_angle    :integer
#  persistent_notes :text
#  position         :integer
#  session_notes    :text
#  stance           :string
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
# Why separate notes?
# - Session notes are logged once, help with injury tracking
# - Persistent notes automatically copy to next workout for setup reminders
class WorkoutExercise < ApplicationRecord
  GRIP_WIDTHS = %w[close normal wide].freeze
  STANCES = %w[narrow normal wide sumo].freeze
  BAR_TYPES = %w[straight ez_curl ssb trap_bar cambered safety_squat].freeze

  belongs_to :workout_block
  belongs_to :exercise
  belongs_to :machine
  has_many :exercise_sets, -> { order(:position) }, dependent: :destroy

  has_one :workout, through: :workout_block

  validates :position, presence: true, numericality: { greater_than: 0 }
  validates :grip_width, inclusion: { in: GRIP_WIDTHS }, allow_nil: true, allow_blank: true
  validates :stance, inclusion: { in: STANCES }, allow_nil: true, allow_blank: true
  validates :bar_type, inclusion: { in: BAR_TYPES }, allow_nil: true, allow_blank: true
  validates :incline_angle, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90, only_integer: true }, allow_nil: true

  scope :ordered, -> { order(:position) }

  before_validation :set_position, on: :create

  # Delegate methods to related models for convenience
  delegate :name, to: :exercise, prefix: true
  delegate :exercise_type, :has_weight, :reps?, :time?, :distance?, to: :exercise

  # Whether any variation modifiers are set
  def has_variations?
    grip_width.present? || stance.present? || incline_angle.present? || bar_type.present?
  end

  # Human-readable variation summary
  def variation_summary
    parts = []
    parts << grip_width_label if grip_width.present?
    parts << stance_label if stance.present?
    parts << "#{incline_angle}°" if incline_angle.present?
    parts << bar_type_label if bar_type.present?
    parts.join(' · ')
  end

  def grip_width_label
    { 'close' => 'Close Grip', 'normal' => 'Normal Grip', 'wide' => 'Wide Grip' }[grip_width]
  end

  def stance_label
    { 'narrow' => 'Narrow', 'normal' => 'Normal', 'wide' => 'Wide', 'sumo' => 'Sumo' }[stance]
  end

  def bar_type_label
    {
      'straight' => 'Straight Bar', 'ez_curl' => 'EZ-Curl', 'ssb' => 'SSB',
      'trap_bar' => 'Trap Bar', 'cambered' => 'Cambered', 'safety_squat' => 'Safety Squat'
    }[bar_type]
  end

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
    workout.user.workout_exercises
      .where(exercise_id: exercise_id, machine_id: machine_id)
      .joins(workout_block: :workout)
      .where('workouts.id != ?', workout.id)
      .where('workouts.finished_at IS NOT NULL')
      .order(Arel.sql('workouts.started_at DESC'))
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

# == Schema Information
#
# Table name: exercise_sets
#
#  id                  :integer          not null, primary key
#  band_tension_kg     :decimal(, )
#  belt                :boolean          default(FALSE), not null
#  chain_weight_kg     :decimal(, )
#  completed_at        :datetime
#  distance_meters     :decimal(, )
#  duration_seconds    :integer
#  is_amrap            :boolean          default(FALSE)
#  is_bfr              :boolean          default(FALSE), not null
#  is_failed           :boolean          default(FALSE), not null
#  is_warmup           :boolean
#  knee_sleeves        :boolean          default(FALSE), not null
#  pain_flag           :boolean          default(FALSE), not null
#  pain_note           :string
#  partial_reps        :integer
#  position            :integer
#  reps                :integer
#  rir                 :integer
#  rpe                 :decimal(, )
#  set_type            :string           default("normal")
#  spotter_assisted    :boolean          default(FALSE), not null
#  straps              :boolean          default(FALSE), not null
#  tempo_concentric    :integer
#  tempo_eccentric     :integer
#  tempo_pause_bottom  :integer
#  tempo_pause_top     :integer
#  weight_kg           :decimal(, )
#  wrist_wraps         :boolean          default(FALSE), not null
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
  # Set types for advanced training methods
  SET_TYPES = %w[normal drop_set rest_pause cluster myo_rep backoff].freeze

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
  validates :set_type, inclusion: { in: SET_TYPES }
  validates :tempo_eccentric, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 30, only_integer: true }, allow_nil: true
  validates :tempo_pause_bottom, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 30, only_integer: true }, allow_nil: true
  validates :tempo_concentric, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 30, only_integer: true }, allow_nil: true
  validates :tempo_pause_top, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 30, only_integer: true }, allow_nil: true
  validates :partial_reps, numericality: { greater_than: 0, only_integer: true }, allow_nil: true
  validates :band_tension_kg, numericality: { greater_than: 0 }, allow_nil: true
  validates :chain_weight_kg, numericality: { greater_than: 0 }, allow_nil: true
  validate :warmup_and_amrap_mutually_exclusive

  scope :ordered, -> { order(:position) }
  scope :warmup, -> { where(is_warmup: true) }
  scope :working, -> { where(is_warmup: false) }  # "Working sets" = not warmup
  scope :amrap, -> { where(is_amrap: true) }
  scope :completed, -> { where.not(completed_at: nil) }
  scope :by_type, ->(type) { where(set_type: type) }
  scope :equipped, -> { where('belt = ? OR knee_sleeves = ? OR wrist_wraps = ? OR straps = ?', true, true, true, true) }
  scope :with_pain, -> { where(pain_flag: true) }
  scope :failed, -> { where(is_failed: true) }
  scope :bfr, -> { where(is_bfr: true) }

  before_validation :set_position, on: :create

  # Set type checks
  def warmup?
    is_warmup == true
  end

  def amrap?
    is_amrap == true
  end

  def working?
    !warmup?
  end

  # Set type checks
  def normal?
    set_type == 'normal'
  end

  def drop_set?
    set_type == 'drop_set'
  end

  def rest_pause?
    set_type == 'rest_pause'
  end

  def cluster?
    set_type == 'cluster'
  end

  def myo_rep?
    set_type == 'myo_rep'
  end

  def backoff?
    set_type == 'backoff'
  end

  def advanced_set_type?
    set_type != 'normal'
  end

  # Equipment checks
  def equipped?
    belt? || knee_sleeves? || wrist_wraps? || straps?
  end

  def equipment_list
    items = []
    items << 'Belt' if belt?
    items << 'Knee Sleeves' if knee_sleeves?
    items << 'Wrist Wraps' if wrist_wraps?
    items << 'Straps' if straps?
    items
  end

  def equipment_badges
    badges = []
    badges << { label: 'B', title: 'Belt', color: 'info' } if belt?
    badges << { label: 'KS', title: 'Knee Sleeves', color: 'info' } if knee_sleeves?
    badges << { label: 'WW', title: 'Wrist Wraps', color: 'info' } if wrist_wraps?
    badges << { label: 'S', title: 'Straps', color: 'info' } if straps?
    badges
  end

  # Outcome checks
  def has_accommodating_resistance?
    band_tension_kg.present? || chain_weight_kg.present?
  end

  # Total effective weight including bands/chains
  def total_load_kg
    (weight_kg || 0) + (band_tension_kg || 0) + (chain_weight_kg || 0)
  end

  # Outcome badges for display
  def outcome_badges
    badges = []
    badges << { label: '✗', title: 'Failed', color: 'danger' } if is_failed?
    badges << { label: 'SP', title: 'Spotter Assisted', color: 'warning' } if spotter_assisted?
    badges << { label: '⚡', title: 'Pain/Discomfort', color: 'danger' } if pain_flag?
    badges << { label: 'BFR', title: 'Blood Flow Restriction', color: 'primary' } if is_bfr?
    badges
  end

  # Human-readable set type label
  def set_type_label
    {
      'normal' => 'Normal',
      'drop_set' => 'Drop Set',
      'rest_pause' => 'Rest-Pause',
      'cluster' => 'Cluster',
      'myo_rep' => 'Myo-Rep',
      'backoff' => 'Back-off'
    }[set_type] || 'Normal'
  end

  # Short badge label for display
  def set_type_badge
    {
      'drop_set' => 'D',
      'rest_pause' => 'RP',
      'cluster' => 'CL',
      'myo_rep' => 'MR',
      'backoff' => 'BO'
    }[set_type]
  end

  # Badge color for set type
  def set_type_color
    {
      'drop_set' => 'danger',
      'rest_pause' => 'warning',
      'cluster' => 'primary',
      'myo_rep' => 'success',
      'backoff' => 'secondary'
    }[set_type] || 'secondary'
  end

  # Tempo methods
  def has_tempo?
    tempo_eccentric.present? || tempo_pause_bottom.present? ||
      tempo_concentric.present? || tempo_pause_top.present?
  end

  # Format tempo as "3-1-2-0" (eccentric-pause-concentric-pause)
  def tempo_display
    return nil unless has_tempo?

    [
      tempo_eccentric || 0,
      tempo_pause_bottom || 0,
      tempo_concentric || 0,
      tempo_pause_top || 0
    ].join('-')
  end

  # Total time under tension for one rep (in seconds)
  def tempo_tut
    return nil unless has_tempo?

    (tempo_eccentric || 0) + (tempo_pause_bottom || 0) +
      (tempo_concentric || 0) + (tempo_pause_top || 0)
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

  # AMRAP sets cannot be warmup sets and vice versa
  def warmup_and_amrap_mutually_exclusive
    if is_warmup && is_amrap
      errors.add(:base, 'A set cannot be both a warmup and AMRAP')
    end
  end

  # Auto-assign position as last set for this exercise when created
  def set_position
    return if position.present?
    max_position = workout_exercise.exercise_sets.maximum(:position) || 0
    self.position = max_position + 1
  end
end

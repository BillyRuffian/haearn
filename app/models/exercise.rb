# == Schema Information
#
# Table name: exercises
#
#  id                   :integer          not null, primary key
#  description          :text
#  exercise_type        :string
#  has_weight           :boolean
#  name                 :string
#  primary_muscle_group :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  user_id              :integer
#
# Indexes
#
#  index_exercises_on_user_id  (user_id)
#
# Foreign Keys
#
#  user_id  (user_id => users.id)
#
class Exercise < ApplicationRecord
  belongs_to :user, optional: true # nil = global/seeded exercise
  has_many :workout_exercises, dependent: :restrict_with_error

  # Exercise types
  EXERCISE_TYPES = %w[reps time distance].freeze

  # Primary muscle groups for volume tracking
  MUSCLE_GROUPS = %w[
    chest
    back
    shoulders
    biceps
    triceps
    forearms
    quadriceps
    hamstrings
    glutes
    calves
    core
    full_body
  ].freeze

  MUSCLE_GROUP_LABELS = {
    'chest' => 'Chest',
    'back' => 'Back',
    'shoulders' => 'Shoulders',
    'biceps' => 'Biceps',
    'triceps' => 'Triceps',
    'forearms' => 'Forearms',
    'quadriceps' => 'Quadriceps',
    'hamstrings' => 'Hamstrings',
    'glutes' => 'Glutes',
    'calves' => 'Calves',
    'core' => 'Core',
    'full_body' => 'Full Body'
  }.freeze

  MUSCLE_GROUP_COLORS = {
    'chest' => '#ff6b35',      # Forge orange (primary accent)
    'back' => '#c94d14',       # Rust light
    'shoulders' => '#a33a0c',  # Rust
    'biceps' => '#7a2d09',     # Rust dark
    'triceps' => '#b8860b',    # Warning gold
    'forearms' => '#8b7355',   # Bronze
    'quadriceps' => '#3d7ea6', # Info blue
    'hamstrings' => '#2d7a3e', # Success green
    'glutes' => '#5a6269',     # Gunmetal
    'calves' => '#71797E',     # Steel
    'core' => '#d4a574',       # Copper
    'full_body' => '#43464b'   # Dark steel
  }.freeze

  validates :name, presence: true
  validates :exercise_type, presence: true, inclusion: { in: EXERCISE_TYPES }
  validates :primary_muscle_group, inclusion: { in: MUSCLE_GROUPS }, allow_blank: true

  scope :global, -> { where(user_id: nil) }
  scope :for_user, ->(user) { where(user_id: [ nil, user.id ]) }
  scope :ordered, -> { order(:name) }

  def global?
    user_id.nil?
  end

  def reps?
    exercise_type == 'reps'
  end

  def time?
    exercise_type == 'time'
  end

  def distance?
    exercise_type == 'distance'
  end
end

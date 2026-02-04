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
    'chest' => '#ff6b35',      # Rust orange
    'back' => '#4ECDC4',       # Teal
    'shoulders' => '#45B7D1',  # Sky blue
    'biceps' => '#96CEB4',     # Sage green
    'triceps' => '#FFEAA7',    # Pale yellow
    'forearms' => '#DDA0DD',   # Plum
    'quadriceps' => '#98D8C8', # Mint
    'hamstrings' => '#F7DC6F', # Mellow yellow
    'glutes' => '#BB8FCE',     # Light purple
    'calves' => '#85C1E9',     # Light blue
    'core' => '#F8B500',       # Gold
    'full_body' => '#71797E'   # Gunmetal
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

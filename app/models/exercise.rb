class Exercise < ApplicationRecord
  belongs_to :user, optional: true # nil = global/seeded exercise
  has_many :workout_exercises, dependent: :restrict_with_error

  # Exercise types
  EXERCISE_TYPES = %w[reps time distance].freeze

  validates :name, presence: true
  validates :exercise_type, presence: true, inclusion: { in: EXERCISE_TYPES }

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

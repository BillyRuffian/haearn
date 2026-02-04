# == Schema Information
#
# Table name: workouts
#
#  id          :integer          not null, primary key
#  finished_at :datetime
#  notes       :text
#  started_at  :datetime
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  gym_id      :integer          not null
#  user_id     :integer          not null
#
# Indexes
#
#  index_workouts_on_gym_id   (gym_id)
#  index_workouts_on_user_id  (user_id)
#
# Foreign Keys
#
#  gym_id   (gym_id => gyms.id)
#  user_id  (user_id => users.id)
#
class Workout < ApplicationRecord
  belongs_to :user
  belongs_to :gym
  has_many :workout_blocks, -> { order(:position) }, dependent: :destroy
  has_many :workout_exercises, through: :workout_blocks
  has_many :exercise_sets, through: :workout_exercises

  validates :gym, presence: { message: 'must be selected' }

  scope :recent, -> { order(started_at: :desc) }
  scope :completed, -> { where.not(finished_at: nil) }
  scope :in_progress, -> { where(finished_at: nil) }

  def in_progress?
    finished_at.nil?
  end

  def completed?
    finished_at.present?
  end

  def duration
    return nil unless started_at
    (finished_at || Time.current) - started_at
  end

  def duration_minutes
    return nil unless duration
    (duration / 60).round
  end

  def total_volume_kg
    exercise_sets.sum { |s| (s.weight_kg || 0) * (s.reps || 0) }
  end

  def finish!
    update!(finished_at: Time.current)
  end
end

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
#  index_workouts_on_created_at               (created_at)
#  index_workouts_on_gym_id                   (gym_id)
#  index_workouts_on_user_id                  (user_id)
#  index_workouts_on_user_id_and_finished_at  (user_id,finished_at)
#
# Foreign Keys
#
#  gym_id   (gym_id => gyms.id)
#  user_id  (user_id => users.id)
#
# Supersets:
# Block with multiple exercises = superset
# User alternates between exercises in the block
# Example: Block A has [Bench Press, Bent Row]
#   Do: A1 set 1 → A2 set 1 → rest → A1 set 2 → A2 set 2 → etc.
class Workout < ApplicationRecord
  ANALYTICS_KEYS = DashboardAnalyticsCache::ANALYTICS_KEYS.freeze
  ANALYTICS_UPDATE_COLUMNS = %w[finished_at started_at gym_id user_id].freeze

  belongs_to :user
  belongs_to :gym
  has_many :workout_blocks, -> { order(:position) }, dependent: :destroy
  has_many :workout_exercises, through: :workout_blocks
  has_many :exercise_sets, through: :workout_exercises

  validates :gym, presence: { message: 'must be selected' }

  scope :recent, -> { order(started_at: :desc) }
  scope :completed, -> { where.not(finished_at: nil) }
  scope :in_progress, -> { where(finished_at: nil) }
  after_commit :invalidate_dashboard_analytics_cache_after_create_destroy, on: %i[create destroy]
  after_commit :invalidate_dashboard_analytics_cache_after_update, on: :update

  # Check workout state
  def in_progress?
    finished_at.nil?
  end

  def completed?
    finished_at.present?
  end

  # Check if workout can be continued (finished less than 1 hour ago)
  def can_continue?
    completed? && finished_at > 1.hour.ago
  end

  # Calculate workout duration (in seconds)
  # For in-progress workouts, calculates up to current time
  def duration
    return nil unless started_at
    (finished_at || Time.current) - started_at
  end

  # Workout duration in minutes (rounded)
  def duration_minutes
    return nil unless duration
    (duration / 60).round
  end

  # Calculate total training volume (weight × reps summed across all sets)
  # Returns value in kg
  def total_volume_kg
    exercise_sets.sum { |s| (s.weight_kg || 0) * (s.reps || 0) }
  end

  # Get list of muscle groups worked in this workout
  # Returns array of muscle group strings (e.g., ["chest", "back", "shoulders"])
  def muscle_groups_worked
    workout_exercises
      .joins(:exercise)
      .where.not(exercises: { primary_muscle_group: nil })
      .pluck(Arel.sql('exercises.primary_muscle_group'))
      .uniq
      .sort
  end

  # Mark workout as complete by setting finished_at timestamp
  def finish!
    update!(finished_at: Time.current)
  end

  private

  def invalidate_dashboard_analytics_cache_after_create_destroy
    DashboardAnalyticsCache.invalidate_for_user!(user_id, keys: ANALYTICS_KEYS)
  end

  def invalidate_dashboard_analytics_cache_after_update
    changed_columns = previous_changes.keys
    return if (changed_columns & ANALYTICS_UPDATE_COLUMNS).empty?

    DashboardAnalyticsCache.invalidate_for_user!(user_id, keys: ANALYTICS_KEYS)
  end
end

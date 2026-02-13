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
require 'test_helper'

class WorkoutTest < ActiveSupport::TestCase
  setup do
    DashboardAnalyticsCache.reset_invalidation_tracking!
    @workout = workouts(:one)
  end

  teardown do
    DashboardAnalyticsCache.reset_invalidation_tracking!
  end

  test 'invalidates dashboard analytics cache after commit' do
    @workout.update!(finished_at: Time.current)

    tokens = DashboardAnalyticsCache.invalidation_tokens
    assert_includes tokens, DashboardAnalyticsCache.invalidation_token(user_id: @workout.user_id, key: 'streaks')
  end

  test 'does not invalidate dashboard analytics cache for non-analytics update' do
    @workout.update!(notes: 'notes only update')

    tokens = DashboardAnalyticsCache.invalidation_tokens
    assert_not_includes tokens, DashboardAnalyticsCache.invalidation_token(user_id: @workout.user_id, key: 'streaks')
  end
end

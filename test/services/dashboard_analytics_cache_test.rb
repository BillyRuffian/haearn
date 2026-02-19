# frozen_string_literal: true

require 'test_helper'

class DashboardAnalyticsCacheTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @store = ActiveSupport::Cache::MemoryStore.new
    DashboardAnalyticsCache.reset_invalidation_tracking!
  end

  teardown do
    DashboardAnalyticsCache.reset_invalidation_tracking!
  end

  test 'fetch stores and returns cached value' do
    value = DashboardAnalyticsCache.fetch(user_id: @user.id, key: 'streaks', cache_store: @store) { { current: 3 } }
    cached = DashboardAnalyticsCache.fetch(user_id: @user.id, key: 'streaks', cache_store: @store) { { current: 9 } }

    assert_equal({ current: 3 }, value)
    assert_equal({ current: 3 }, cached)
  end

  test 'fetch records miss then hit metrics for the day' do
    DashboardAnalyticsCache.reset_metrics_for_user!(user_id: @user.id, cache_store: @store)

    DashboardAnalyticsCache.fetch(user_id: @user.id, key: 'streaks', cache_store: @store) { { current: 3 } }
    DashboardAnalyticsCache.fetch(user_id: @user.id, key: 'streaks', cache_store: @store) { { current: 9 } }

    metrics = DashboardAnalyticsCache.metrics_for_user(user_id: @user.id, cache_store: @store)
    assert_equal 1, metrics['cache_miss']
    assert_equal 1, metrics['cache_hit']
  end

  test 'invalidate_for_user bumps all analytics key versions for the user' do
    DashboardAnalyticsCache::ANALYTICS_KEYS.each do |key|
      @store.write(DashboardAnalyticsCache.cache_key(user_id: @user.id, key: key, cache_store: @store), "v:#{key}")
    end

    DashboardAnalyticsCache.invalidate_for_user!(@user.id, cache_store: @store)

    DashboardAnalyticsCache::ANALYTICS_KEYS.each do |key|
      assert_equal 2, DashboardAnalyticsCache.version_for(user_id: @user.id, key:, cache_store: @store)
    end
  end

  test 'invalidate_for_user dedupes repeated invalidation for same user in current context' do
    spy_store = ActiveSupport::Cache::MemoryStore.new
    DashboardAnalyticsCache.reset_invalidation_tracking!

    DashboardAnalyticsCache.invalidate_for_user!(@user.id, cache_store: spy_store)
    DashboardAnalyticsCache.invalidate_for_user!(@user.id, cache_store: spy_store)

    DashboardAnalyticsCache::ANALYTICS_KEYS.each do |key|
      assert_equal 2, DashboardAnalyticsCache.version_for(user_id: @user.id, key:, cache_store: spy_store)
    end
  end

  test 'invalidate_for_user records invalidation metric only for non-skipped deletes' do
    DashboardAnalyticsCache.reset_metrics_for_user!(user_id: @user.id, cache_store: @store)

    DashboardAnalyticsCache.invalidate_for_user!(@user.id, keys: %w[streaks], cache_store: @store)
    DashboardAnalyticsCache.invalidate_for_user!(@user.id, keys: %w[streaks], cache_store: @store)

    metrics = DashboardAnalyticsCache.metrics_for_user(user_id: @user.id, cache_store: @store)
    assert_equal 1, metrics['invalidation']
  end

  test 'invalidate_for_user only clears requested key subset' do
    spy_store = ActiveSupport::Cache::MemoryStore.new
    keys = %w[streaks tonnage]

    DashboardAnalyticsCache.invalidate_for_user!(@user.id, keys:, cache_store: spy_store)

    keys.each do |key|
      assert_equal 2, DashboardAnalyticsCache.version_for(user_id: @user.id, key:, cache_store: spy_store)
    end

    untouched_key = (DashboardAnalyticsCache::ANALYTICS_KEYS - keys).first
    assert_equal 1, DashboardAnalyticsCache.version_for(user_id: @user.id, key: untouched_key, cache_store: spy_store)
  end

  test 'version bump causes subsequent fetch to miss and recompute only bumped key' do
    first = DashboardAnalyticsCache.fetch(user_id: @user.id, key: 'streaks', cache_store: @store) { { current: 3 } }

    DashboardAnalyticsCache.invalidate_for_user!(@user.id, keys: %w[streaks], cache_store: @store)

    second = DashboardAnalyticsCache.fetch(user_id: @user.id, key: 'streaks', cache_store: @store) { { current: 9 } }

    assert_equal({ current: 3 }, first)
    assert_equal({ current: 9 }, second)
  end
end

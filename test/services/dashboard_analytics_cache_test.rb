# frozen_string_literal: true

require 'test_helper'

class DashboardAnalyticsCacheTest < ActiveSupport::TestCase
  class SpyStore
    attr_reader :deleted_keys

    def initialize
      @store = {}
      @deleted_keys = []
    end

    def fetch(key, _opts = {})
      return @store[key] if @store.key?(key)

      @store[key] = yield
    end

    def write(key, value, _opts = {})
      @store[key] = value
    end

    def read(key)
      @store[key]
    end

    def delete(key)
      @deleted_keys << key
      @store.delete(key)
    end
  end

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

  test 'invalidate_for_user removes all analytics keys for the user' do
    DashboardAnalyticsCache::ANALYTICS_KEYS.each do |key|
      @store.write(DashboardAnalyticsCache.cache_key(user_id: @user.id, key: key), "v:#{key}")
    end

    DashboardAnalyticsCache.invalidate_for_user!(@user.id, cache_store: @store)

    DashboardAnalyticsCache::ANALYTICS_KEYS.each do |key|
      assert_nil @store.read(DashboardAnalyticsCache.cache_key(user_id: @user.id, key: key))
    end
  end

  test 'invalidate_for_user dedupes repeated invalidation for same user in current context' do
    spy_store = SpyStore.new
    DashboardAnalyticsCache.reset_invalidation_tracking!

    DashboardAnalyticsCache.invalidate_for_user!(@user.id, cache_store: spy_store)
    DashboardAnalyticsCache.invalidate_for_user!(@user.id, cache_store: spy_store)

    assert_equal DashboardAnalyticsCache::ANALYTICS_KEYS.size, spy_store.deleted_keys.size
  end

  test 'invalidate_for_user records invalidation metric only for non-skipped deletes' do
    DashboardAnalyticsCache.reset_metrics_for_user!(user_id: @user.id, cache_store: @store)

    DashboardAnalyticsCache.invalidate_for_user!(@user.id, keys: %w[streaks], cache_store: @store)
    DashboardAnalyticsCache.invalidate_for_user!(@user.id, keys: %w[streaks], cache_store: @store)

    metrics = DashboardAnalyticsCache.metrics_for_user(user_id: @user.id, cache_store: @store)
    assert_equal 1, metrics['invalidation']
  end

  test 'invalidate_for_user only clears requested key subset' do
    spy_store = SpyStore.new
    keys = %w[streaks tonnage]

    DashboardAnalyticsCache.invalidate_for_user!(@user.id, keys:, cache_store: spy_store)

    expected_deleted = keys.map { |key| DashboardAnalyticsCache.cache_key(user_id: @user.id, key:) }.sort
    assert_equal expected_deleted, spy_store.deleted_keys.sort
  end
end

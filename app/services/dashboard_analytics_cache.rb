# frozen_string_literal: true

require 'set'

# Centralizes dashboard analytics cache keys and invalidation.
class DashboardAnalyticsCache
  ANALYTICS_KEYS = %w[
    pr_timeline
    consistency
    rep_range_distribution
    exercise_frequency
    streaks
    week_comparison
    tonnage
    plateaus
    training_density
    muscle_group_volume
    muscle_balance
  ].freeze

  METRIC_TYPES = %w[cache_hit cache_miss invalidation].freeze
  METRICS_TTL = 8.days

  def self.fetch(user_id:, key:, expires_in: 3.minutes, cache_store: self.cache_store, &block)
    cache_key_value = cache_key(user_id:, key:, cache_store:)
    cached = cache_store.read(cache_key_value)
    hit = !cached.nil?

    if hit
      increment_metric(user_id:, metric_type: 'cache_hit', cache_store:)
      instrument_fetch(user_id:, key:, cache_key: cache_key_value, hit:)
      return cached
    end

    value = block.call
    cache_store.write(cache_key_value, value, expires_in:)
    increment_metric(user_id:, metric_type: 'cache_miss', cache_store:)
    instrument_fetch(user_id:, key:, cache_key: cache_key_value, hit: false)
    value
  end

  def self.invalidate_for_user!(user_id, keys: ANALYTICS_KEYS, cache_store: self.cache_store)
    return unless user_id

    keys.each do |key|
      token = invalidation_token(user_id:, key:)
      if invalidation_tokens.include?(token)
        instrument_invalidation(user_id:, key:, skipped: true)
        next
      end

      bump_version!(user_id:, key:, cache_store:)
      increment_metric(user_id:, metric_type: 'invalidation', cache_store:)
      instrument_invalidation(user_id:, key:, skipped: false)
      invalidation_tokens << token
    end
  end

  def self.cache_key(user_id:, key:, cache_store: self.cache_store)
    version = version_for(user_id:, key:, cache_store:)
    "dashboard:analytics:v2:user:#{user_id}:#{key}:version:#{version}"
  end

  def self.cache_store
    Rails.cache
  end

  def self.reset_invalidation_tracking!
    Current.dashboard_cache_invalidation_tokens = Set.new
  end

  def self.invalidation_tokens
    Current.dashboard_cache_invalidation_tokens ||= Set.new
  end

  def self.invalidation_token(user_id:, key:)
    "#{user_id}:#{key}"
  end

  def self.metrics_for_user(user_id:, date: Date.current, cache_store: self.cache_store)
    METRIC_TYPES.index_with do |metric_type|
      metric_value = cache_store.read(metric_key(user_id:, date:, metric_type:))
      metric_value.to_i
    end
  end

  def self.reset_metrics_for_user!(user_id:, date: Date.current, cache_store: self.cache_store)
    METRIC_TYPES.each do |metric_type|
      cache_store.delete(metric_key(user_id:, date:, metric_type:))
    end
  end

  def self.increment_metric(user_id:, metric_type:, cache_store:)
    key = metric_key(user_id:, date: Date.current, metric_type:)

    if cache_store.respond_to?(:increment)
      cache_store.increment(key, 1, initial: 0, expires_in: METRICS_TTL)
    else
      value = cache_store.read(key).to_i + 1
      cache_store.write(key, value, expires_in: METRICS_TTL)
    end
  end

  def self.metric_key(user_id:, date:, metric_type:)
    "dashboard:analytics:metrics:user:#{user_id}:date:#{date.iso8601}:#{metric_type}"
  end

  def self.version_for(user_id:, key:, cache_store:)
    version = cache_store.read(version_key(user_id:, key:))
    version.to_i.positive? ? version.to_i : 1
  end

  def self.bump_version!(user_id:, key:, cache_store:)
    next_version = version_for(user_id:, key:, cache_store:) + 1
    cache_store.write(version_key(user_id:, key:), next_version, expires_in: 30.days)
  end

  def self.version_key(user_id:, key:)
    "dashboard:analytics:version:user:#{user_id}:#{key}"
  end

  def self.instrument_fetch(user_id:, key:, cache_key:, hit:)
    ActiveSupport::Notifications.instrument(
      'dashboard_analytics_cache.fetch',
      user_id: user_id,
      analytics_key: key,
      cache_key: cache_key,
      hit: hit
    )
  end

  def self.instrument_invalidation(user_id:, key:, skipped:)
    ActiveSupport::Notifications.instrument(
      'dashboard_analytics_cache.invalidate',
      user_id: user_id,
      analytics_key: key,
      skipped: skipped
    )
  end
end

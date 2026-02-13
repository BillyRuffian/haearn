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

  def self.fetch(user_id:, key:, expires_in: 3.minutes, cache_store: self.cache_store, &block)
    cache_store.fetch(cache_key(user_id:, key:), expires_in:, &block)
  end

  def self.invalidate_for_user!(user_id, keys: ANALYTICS_KEYS, cache_store: self.cache_store)
    return unless user_id

    keys.each do |key|
      token = invalidation_token(user_id:, key:)
      next if invalidation_tokens.include?(token)

      cache_store.delete(cache_key(user_id:, key:))
      invalidation_tokens << token
    end
  end

  def self.cache_key(user_id:, key:)
    "dashboard:analytics:v1:user:#{user_id}:#{key}"
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
end

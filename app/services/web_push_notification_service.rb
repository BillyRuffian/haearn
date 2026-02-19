# frozen_string_literal: true
require 'webpush'

# Sends persisted notifications to browser push subscribers using VAPID.
class WebPushNotificationService
  METRICS_TTL = 8.days
  DEFAULT_MAX_RETRIES = 2
  BASE_BACKOFF_SECONDS = 0.25

  def initialize(
    user:,
    push_client: Webpush,
    push_config: WebPushConfig,
    metrics_cache_store: Rails.cache,
    max_retries: DEFAULT_MAX_RETRIES,
    sleeper: ->(seconds) { sleep(seconds) }
  )
    @user = user
    @push_client = push_client
    @push_config = push_config
    @metrics_cache_store = metrics_cache_store
    @max_retries = max_retries
    @sleeper = sleeper
  end

  def deliver_notification(notification)
    return unless notification
    return unless @push_config.configured?
    return unless @user.web_push_enabled_for?(notification.kind)
    return if @user.push_subscriptions.empty?

    payload = {
      title: notification.title,
      options: {
        body: notification.message,
        icon: '/icon.png',
        badge: '/icon.png',
        tag: "haearn-#{notification.kind}-#{notification.id}",
        data: {
          notification_id: notification.id,
          kind: notification.kind,
          path: notification_path(notification)
        }
      }
    }

    @user.push_subscriptions.find_each do |subscription|
      send_payload!(subscription:, payload:)
    end
  end

  private

  def notification_path(notification)
    case notification.kind
    when 'readiness', 'plateau'
      exercise_id = notification.metadata['exercise_id']
      machine_id = notification.metadata['machine_id']
      return '/' unless exercise_id

      machine_id.present? ? "/exercises/#{exercise_id}/history?machine_id=#{machine_id}" : "/exercises/#{exercise_id}/history"
    when 'streak_risk'
      '/workouts/new'
    when 'volume_drop'
      '/workouts'
    when 'rest_timer'
      workout_id = notification.metadata['workout_id']
      workout_id.present? ? "/workouts/#{workout_id}" : '/'
    else
      '/notifications'
    end
  end

  def send_payload!(subscription:, payload:)
    host = endpoint_host(subscription.endpoint)
    attempt = 0

    begin
      attempt += 1
      increment_delivery_metric(type: 'attempt', host:)

      @push_client.payload_send(
        endpoint: subscription.endpoint,
        message: payload.to_json,
        p256dh: subscription.p256dh_key,
        auth: subscription.auth_key,
        vapid: @push_config.vapid_options
      )

      increment_delivery_metric(type: 'success', host:)
      subscription.touch(:updated_at)
    rescue Webpush::ExpiredSubscription, Webpush::InvalidSubscription => e
      increment_delivery_metric(type: 'failure', host:, error_class: e.class.name)
      handle_subscription_error(subscription, e)
    rescue Webpush::ResponseError => e
      increment_delivery_metric(type: 'failure', host:, error_class: e.class.name)

      if retryable_webpush_error?(e) && retryable_attempt?(attempt)
        schedule_retry(subscription:, attempt:, error: e)
        retry
      end

      Rails.logger.warn("[WebPush] Failed for subscription #{subscription.id}: #{e.class}: #{e.message}")
    rescue StandardError => e
      increment_delivery_metric(type: 'failure', host:, error_class: e.class.name)

      if retryable_standard_error?(e) && retryable_attempt?(attempt)
        schedule_retry(subscription:, attempt:, error: e)
        retry
      end

      Rails.logger.warn("[WebPush] Failed for subscription #{subscription.id}: #{e.class}: #{e.message}")
    end
  end

  def handle_subscription_error(subscription, error)
    Rails.logger.info("[WebPush] Removing invalid subscription #{subscription.id}: #{error.class}")
    subscription.destroy
  end

  def endpoint_host(endpoint)
    self.class.endpoint_host(endpoint)
  end

  def increment_delivery_metric(type:, host:, error_class: nil)
    self.class.increment_metric(type:, host:, error_class:, cache_store: @metrics_cache_store)
  end

  def retryable_attempt?(attempt)
    attempt <= @max_retries
  end

  def schedule_retry(subscription:, attempt:, error:)
    delay = (BASE_BACKOFF_SECONDS * (2**(attempt - 1))).round(3)
    Rails.logger.info("[WebPush] Retrying subscription #{subscription.id} in #{delay}s after #{error.class}")
    @sleeper.call(delay)
  end

  def retryable_webpush_error?(error)
    return true if error.is_a?(Webpush::TooManyRequests) || error.is_a?(Webpush::PushServiceError)

    code = error.response&.respond_to?(:code) ? error.response.code.to_i : 0
    code == 429 || code >= 500
  end

  def retryable_standard_error?(error)
    transient = [
      Timeout::Error,
      SocketError,
      EOFError,
      Errno::ECONNRESET,
      Errno::ETIMEDOUT
    ]

    transient << Net::OpenTimeout if defined?(Net::OpenTimeout)
    transient << Net::ReadTimeout if defined?(Net::ReadTimeout)
    transient << OpenSSL::SSL::SSLError if defined?(OpenSSL::SSL::SSLError)

    transient.any? { |klass| error.is_a?(klass) }
  end

  def self.endpoint_host(endpoint)
    URI.parse(endpoint).host.to_s.downcase.presence || 'unknown'
  rescue URI::InvalidURIError, ArgumentError
    'unknown'
  end

  def self.metrics_for(date: Date.current, cache_store: Rails.cache)
    {
      attempts_by_host: metric_bucket(type: 'attempt', date:, cache_store:),
      successes_by_host: metric_bucket(type: 'success', date:, cache_store:),
      failures_by_host_and_error: failure_metric_bucket(date:, cache_store:)
    }
  end

  def self.reset_metrics!(date: Date.current, cache_store: Rails.cache)
    delete_matched(cache_store, "web_push:metrics:date:#{date.iso8601}:*")
  end

  def self.increment_metric(type:, host:, error_class: nil, cache_store: Rails.cache)
    key = metric_key(type:, host:, date: Date.current, error_class:)

    if cache_store.respond_to?(:increment)
      cache_store.increment(key, 1, initial: 0, expires_in: METRICS_TTL)
    else
      cache_store.write(key, cache_store.read(key).to_i + 1, expires_in: METRICS_TTL)
    end
  end

  def self.metric_key(type:, host:, date:, error_class: nil)
    base = "web_push:metrics:date:#{date.iso8601}:type:#{type}:host:#{host}"
    error_class.present? ? "#{base}:error:#{error_class}" : base
  end

  def self.metric_bucket(type:, date:, cache_store:)
    read_matched(cache_store, "web_push:metrics:date:#{date.iso8601}:type:#{type}:host:*")
      .each_with_object({}) do |(key, value), bucket|
        host = key.split(':host:').last
        bucket[host] = value.to_i
      end
  end

  def self.failure_metric_bucket(date:, cache_store:)
    read_matched(cache_store, "web_push:metrics:date:#{date.iso8601}:type:failure:host:*:error:*")
      .each_with_object({}) do |(key, value), bucket|
        host = key.split(':host:').last.split(':error:').first
        error = key.split(':error:').last
        bucket["#{host}|#{error}"] = value.to_i
      end
  end

  def self.read_matched(cache_store, pattern)
    return {} unless cache_store.respond_to?(:read_multi)

    # MemoryStore supports key enumeration via delete_matched internals; use a non-destructive scan.
    keys = cache_store.instance_variable_get(:@data)&.keys&.grep(glob_to_regex(pattern)) || []
    return {} if keys.empty?

    cache_store.read_multi(*keys)
  rescue StandardError
    {}
  end

  def self.delete_matched(cache_store, pattern)
    if cache_store.respond_to?(:delete_matched)
      cache_store.delete_matched(pattern)
      return
    end

    keys = cache_store.instance_variable_get(:@data)&.keys&.grep(glob_to_regex(pattern)) || []
    keys.each { |key| cache_store.delete(key) }
  rescue StandardError
    nil
  end

  def self.glob_to_regex(pattern)
    Regexp.new("\\A#{Regexp.escape(pattern).gsub('\\*', '.*')}\\z")
  end
end

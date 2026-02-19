require 'test_helper'

class WebPushNotificationServiceTest < ActiveSupport::TestCase
  class PushBoom < StandardError; end

  FakeConfig = Struct.new(:configured, :vapid) do
    def configured?
      configured
    end

    def vapid_options
      vapid
    end
  end

  class FakePushClient
    attr_reader :sent_payloads

    def initialize(failures: {})
      @sent_payloads = []
      @failures = failures.transform_values(&:dup)
    end

    def payload_send(**kwargs)
      endpoint = kwargs[:endpoint]
      queued = @failures[endpoint]
      raise queued.shift if queued.present?

      @sent_payloads << kwargs
      true
    end
  end

  setup do
    @user = users(:one)
    @cache_store = ActiveSupport::Cache::MemoryStore.new
    WebPushNotificationService.reset_metrics!(cache_store: @cache_store)
    @notification = @user.notifications.create!(
      kind: 'streak_risk',
      severity: 'warning',
      title: 'Streak Warning',
      message: 'Train today to keep momentum.',
      dedupe_key: "test-webpush-#{SecureRandom.hex(4)}",
      metadata: {}
    )
  end

  test 'does not attempt delivery when web push is not configured' do
    @user.push_subscriptions.create!(
      endpoint: 'https://example.push/subscriptions/no-config',
      p256dh_key: 'test-p256dh',
      auth_key: 'test-auth'
    )

    push_client = FakePushClient.new
    config = FakeConfig.new(false, nil)

    WebPushNotificationService
      .new(user: @user, push_client:, push_config: config, metrics_cache_store: @cache_store)
      .deliver_notification(@notification)

    assert_empty push_client.sent_payloads
  end

  test 'sends payload to each subscription when configured' do
    @user.push_subscriptions.create!(
      endpoint: 'https://example.push/subscriptions/one',
      p256dh_key: 'test-p256dh-1',
      auth_key: 'test-auth-1'
    )
    @user.push_subscriptions.create!(
      endpoint: 'https://example.push/subscriptions/two',
      p256dh_key: 'test-p256dh-2',
      auth_key: 'test-auth-2'
    )

    push_client = FakePushClient.new
    config = FakeConfig.new(true, { subject: 'mailto:test@example.com', public_key: 'pub', private_key: 'priv' })

    WebPushNotificationService
      .new(user: @user, push_client:, push_config: config, metrics_cache_store: @cache_store)
      .deliver_notification(@notification)

    assert_equal 2, push_client.sent_payloads.size
    assert push_client.sent_payloads.all? { |payload| payload[:endpoint].include?('https://example.push/subscriptions/') }
  end

  test 'records attempt and success counters by endpoint host' do
    @user.push_subscriptions.create!(
      endpoint: 'https://updates.push.example/subscriptions/one',
      p256dh_key: 'test-p256dh-1',
      auth_key: 'test-auth-1'
    )

    push_client = FakePushClient.new
    config = FakeConfig.new(true, { subject: 'mailto:test@example.com', public_key: 'pub', private_key: 'priv' })
    WebPushNotificationService
      .new(user: @user, push_client:, push_config: config, metrics_cache_store: @cache_store)
      .deliver_notification(@notification)

    metrics = WebPushNotificationService.metrics_for(cache_store: @cache_store)
    assert_equal 1, metrics[:attempts_by_host]['updates.push.example']
    assert_equal 1, metrics[:successes_by_host]['updates.push.example']
    assert_empty metrics[:failures_by_host_and_error]
  end

  test 'records failure counters by endpoint host and error class' do
    endpoint = 'https://fcm.googleapis.com/fcm/send/fail-case'
    @user.push_subscriptions.create!(
      endpoint: endpoint,
      p256dh_key: 'test-p256dh-f',
      auth_key: 'test-auth-f'
    )

    push_client = FakePushClient.new(failures: { endpoint => [ PushBoom.new('push failed') ] })
    config = FakeConfig.new(true, { subject: 'mailto:test@example.com', public_key: 'pub', private_key: 'priv' })
    WebPushNotificationService
      .new(user: @user, push_client:, push_config: config, metrics_cache_store: @cache_store)
      .deliver_notification(@notification)

    metrics = WebPushNotificationService.metrics_for(cache_store: @cache_store)
    assert_equal 1, metrics[:attempts_by_host]['fcm.googleapis.com']
    assert_equal 1, metrics[:failures_by_host_and_error]['fcm.googleapis.com|WebPushNotificationServiceTest::PushBoom']
  end

  test 'retries transient standard error with backoff and succeeds' do
    endpoint = 'https://fcm.googleapis.com/fcm/send/retry-standard'
    @user.push_subscriptions.create!(
      endpoint: endpoint,
      p256dh_key: 'test-p256dh-r1',
      auth_key: 'test-auth-r1'
    )

    push_client = FakePushClient.new(failures: { endpoint => [ Timeout::Error.new('temporary timeout') ] })
    config = FakeConfig.new(true, { subject: 'mailto:test@example.com', public_key: 'pub', private_key: 'priv' })
    sleeps = []

    WebPushNotificationService
      .new(
        user: @user,
        push_client:,
        push_config: config,
        metrics_cache_store: @cache_store,
        sleeper: ->(seconds) { sleeps << seconds }
      )
      .deliver_notification(@notification)

    metrics = WebPushNotificationService.metrics_for(cache_store: @cache_store)
    assert_equal 2, metrics[:attempts_by_host]['fcm.googleapis.com']
    assert_equal 1, metrics[:successes_by_host]['fcm.googleapis.com']
    assert_equal 1, metrics[:failures_by_host_and_error]['fcm.googleapis.com|Timeout::Error']
    assert_equal [0.25], sleeps
  end

  test 'retries Webpush::TooManyRequests and succeeds' do
    endpoint = 'https://updates.push.example/subscriptions/retry-429'
    @user.push_subscriptions.create!(
      endpoint: endpoint,
      p256dh_key: 'test-p256dh-r2',
      auth_key: 'test-auth-r2'
    )

    response = Struct.new(:code, :body).new('429', 'too many requests')
    error = Webpush::TooManyRequests.new(response, 'updates.push.example')
    push_client = FakePushClient.new(failures: { endpoint => [ error ] })
    config = FakeConfig.new(true, { subject: 'mailto:test@example.com', public_key: 'pub', private_key: 'priv' })
    sleeps = []

    WebPushNotificationService
      .new(
        user: @user,
        push_client:,
        push_config: config,
        metrics_cache_store: @cache_store,
        sleeper: ->(seconds) { sleeps << seconds }
      )
      .deliver_notification(@notification)

    metrics = WebPushNotificationService.metrics_for(cache_store: @cache_store)
    assert_equal 2, metrics[:attempts_by_host]['updates.push.example']
    assert_equal 1, metrics[:successes_by_host]['updates.push.example']
    assert_equal 1, metrics[:failures_by_host_and_error]['updates.push.example|Webpush::TooManyRequests']
    assert_equal [0.25], sleeps
  end

  test 'does not retry non-transient standard error' do
    endpoint = 'https://updates.push.example/subscriptions/no-retry'
    @user.push_subscriptions.create!(
      endpoint: endpoint,
      p256dh_key: 'test-p256dh-r3',
      auth_key: 'test-auth-r3'
    )

    push_client = FakePushClient.new(failures: { endpoint => [ PushBoom.new('fatal') ] })
    config = FakeConfig.new(true, { subject: 'mailto:test@example.com', public_key: 'pub', private_key: 'priv' })
    sleeps = []

    WebPushNotificationService
      .new(
        user: @user,
        push_client:,
        push_config: config,
        metrics_cache_store: @cache_store,
        sleeper: ->(seconds) { sleeps << seconds }
      )
      .deliver_notification(@notification)

    metrics = WebPushNotificationService.metrics_for(cache_store: @cache_store)
    assert_equal 1, metrics[:attempts_by_host]['updates.push.example']
    assert_nil metrics[:successes_by_host]['updates.push.example']
    assert_equal 1, metrics[:failures_by_host_and_error]['updates.push.example|WebPushNotificationServiceTest::PushBoom']
    assert_empty sleeps
  end
end

require 'test_helper'

class WebPushNotificationServiceTest < ActiveSupport::TestCase
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

    def initialize
      @sent_payloads = []
    end

    def payload_send(**kwargs)
      @sent_payloads << kwargs
      true
    end
  end

  setup do
    @user = users(:one)
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

    WebPushNotificationService.new(user: @user, push_client:, push_config: config).deliver_notification(@notification)

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

    WebPushNotificationService.new(user: @user, push_client:, push_config: config).deliver_notification(@notification)

    assert_equal 2, push_client.sent_payloads.size
    assert push_client.sent_payloads.all? { |payload| payload[:endpoint].include?('https://example.push/subscriptions/') }
  end
end

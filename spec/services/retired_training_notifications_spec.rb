require 'rails_helper'

RSpec.describe 'Retired training notifications' do
  let(:user) { users(:system) }

  it 'rejects new legacy alerts and suppresses push delivery of saved legacy alerts regardless of preferences' do
    user.push_subscriptions.create!(endpoint: 'https://push.example.com/retired', p256dh_key: 'key', auth_key: 'auth')
    push_client = double('Push client')
    push_config = double('Push config', configured?: true)
    expect(push_client).not_to receive(:payload_send)
    service = WebPushNotificationService.new(user: user, push_client: push_client, push_config: push_config)

    Notification::RETIRED_KINDS.each do |kind|
      notification = user.notifications.build(kind: kind, title: 'Old advice', message: 'Old advice', dedupe_key: kind)
      expect(notification).not_to be_valid
      expect(notification.errors[:kind]).to be_present
      expect(user.notification_enabled_for?(kind)).to be(false)
      expect(user.web_push_enabled_for?(kind)).to be(false)
      service.deliver_notification(notification)
    end
  end

  it 'no longer registers plateau analytics for calculation or cache invalidation' do
    expect(DashboardAnalyticsCache::ANALYTICS_KEYS).not_to include('plateaus')
    expect(DashboardAnalyticsCalculator::KEY_METHODS).not_to have_key('plateaus')
  end
end

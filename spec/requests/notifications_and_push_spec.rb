require 'rails_helper'

RSpec.describe 'Notifications and push subscriptions', type: :request do
  let(:user) { users(:one) }

  before do
    sign_in_as(user)
  end

  it 'creates and removes a push subscription for the current user' do
    payload = {
      subscription: {
        endpoint: 'https://push.example.com/subscriptions/abc123',
        expiration_time: nil,
        keys: {
          p256dh: 'p256dh-test-key',
          auth: 'auth-test-key'
        }
      }
    }

    expect do
      post push_subscriptions_path, params: payload, as: :json
    end.to change(user.push_subscriptions, :count).by(1)
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['ok']).to eq(true)

    expect do
      delete push_subscriptions_path, params: { endpoint: payload[:subscription][:endpoint] }, as: :json
    end.to change(user.push_subscriptions, :count).by(-1)
    expect(response).to have_http_status(:ok)
  end

  it 'persists rest timer notifications and de-dupes by completed_at_ms' do
    workout = user.workouts.create!(gym: gyms(:one), started_at: Time.current, finished_at: nil)
    allow_any_instance_of(WebPushNotificationService).to receive(:deliver_notification)

    expect do
      post rest_timer_expired_notifications_path, params: { completed_at_ms: 1_706_000_000_123 }, as: :json
    end.to change(user.notifications.where(kind: 'rest_timer'), :count).by(1)
    expect(response).to have_http_status(:ok)
    parsed = JSON.parse(response.body)
    expect(parsed['ok']).to eq(true)
    expect(parsed['notification_id']).to be_present

    expect do
      post rest_timer_expired_notifications_path, params: { completed_at_ms: 1_706_000_000_123 }, as: :json
    end.not_to change(user.notifications.where(kind: 'rest_timer'), :count)
    expect(response).to have_http_status(:ok)

    notification = user.notifications.find(parsed['notification_id'])
    expect(notification.metadata['workout_id']).to eq(workout.id)
  end
end

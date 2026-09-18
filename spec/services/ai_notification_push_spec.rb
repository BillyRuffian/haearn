require 'rails_helper'

RSpec.describe 'AI notification push payload' do
  include_context 'AI coaching'
  let(:user) { users(:one) }
  let(:workout) { coaching_workout }
  let(:push_client) { double('push client', payload_send: nil) }
  let(:config) { double('push config', configured?: true, vapid_options: {}) }

  before do
    allow(responses_api).to receive(:create) { api_response(coaching_response(Ai::WorkoutContextBuilder.new(workout).call)) }
    user.push_subscriptions.create!(endpoint: 'https://push.example/ai', p256dh_key: 'test-key', auth_key: 'test-auth')
    AnalyseWorkoutJob.perform_now(workout.workout_analyses.sole.id)
  end

  it 'sends a generic alert, the exact review URL, and a count excluding retired advice and rest timers' do
    notification = workout.workout_analyses.sole.notification
    WebPushNotificationService.new(user: user, push_client: push_client, push_config: config).deliver_notification(notification)
    expect(push_client).to have_received(:payload_send) do |**arguments|
      payload = JSON.parse(arguments[:message])
      expect(payload).to include('unread_count' => 1, 'user_id' => user.id)
      expect(payload.dig('options', 'data')).to include('notification_id' => notification.id,
        'path' => notification.action_path, 'kind' => 'workout_analysis', 'user_id' => user.id)
      expect(payload.dig('options', 'body')).not_to include('37.5', 'useful reps')
    end
  end

  it 'honors the AI push preference without deleting the in-app notification' do
    user.update!(notify_ai_analysis_push: false)
    notification = workout.workout_analyses.sole.notification
    WebPushNotificationService.new(user: user, push_client: push_client, push_config: config).deliver_notification(notification)
    expect(push_client).not_to have_received(:payload_send)
    expect(user.notifications.center.unread).to include(notification)
  end
end

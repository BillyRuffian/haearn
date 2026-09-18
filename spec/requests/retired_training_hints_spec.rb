require 'rails_helper'

RSpec.describe 'Retired training hints', type: :request do
  let(:user) { users(:system) }

  before do
    sign_in_as(user)
  end

  it 'keeps old read and unread advice out of notification pages, feeds, and counts' do
    Notification::RETIRED_KINDS.each do |kind|
      [ nil, Time.current ].each_with_index do |read_at, index|
        # Simulate notifications persisted before these kinds were retired.
        user.notifications.insert_all!([
          { kind: kind, severity: 'warning', title: "Retired #{kind} #{index}",
            message: 'Legacy training advice', dedupe_key: "retired:#{kind}:#{index}",
            read_at: read_at, metadata: {} }
        ])
      end
    end

    expect do
      get feed_notifications_path, as: :json
    end.not_to change(Notification, :count)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('unread_count' => 0, 'notifications' => [])

    get notifications_path
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('Retired ', 'Legacy training advice', 'Ready to Progress')
    expect(response.body).to include('No notifications yet.')

    patch read_notification_path(notifications(:system_unread_readiness)), as: :json
    expect(response).to have_http_status(:not_found)
  end

  it 'removes hint panels and settings while retaining workout AI coaching and factual analytics' do
    [ root_path, analytics_path, settings_path,
      workout_path(workouts(:active_logging)), workout_path(workouts(:previous_logging)),
      history_exercise_path(exercises(:system_press)) ].each do |path|
      get path
      expect(response).to have_http_status(:ok), path
      expect(response.body).not_to include('Ready to Progress', 'Progression Updates',
        'Plateau Alert', 'Weeks Stuck', 'Performance Analysis', 'Progression Rep Target',
        'name="user[progression_rep_target]"')
    end

    get workout_path(workouts(:previous_logging))
    expect(response.body).to include('id="ai-coaching"')

    get analytics_path
    expect(response.body).to include('analytics-chart')
  end

  it 'does not allow stale clients to change the retired progression setting' do
    previous_target = user.progression_rep_target
    patch settings_path, params: { user: { progression_rep_target: 15, preferred_unit: 'lbs' } }

    expect(response).to redirect_to(settings_path)
    expect(user.reload.progression_rep_target).to eq(previous_target)
    expect(user.preferred_unit).to eq('lbs')
  end
end

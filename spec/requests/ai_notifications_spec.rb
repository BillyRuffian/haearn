require 'rails_helper'

RSpec.describe 'AI review notifications', type: :request do
  include_context 'AI coaching'
  include ActiveSupport::Testing::TimeHelpers
  let(:user) { users(:one) }
  let(:workout) { coaching_workout }
  let(:analysis) { workout.workout_analyses.sole }

  before do
    sign_in_as(user)
    allow(responses_api).to receive(:create) { api_response(coaching_response(Ai::WorkoutContextBuilder.new(workout).call)) }
  end

  def complete_review
    AnalyseWorkoutJob.perform_now(analysis.id)
    analysis.reload.notification
  end

  it 'exposes the review in the feed with its exact version and an authoritative uncached badge count' do
    notification = complete_review
    get feed_notifications_path, as: :json
    expect(response.parsed_body['unread_count']).to eq(1)
    expect(response.parsed_body['notifications'].sole).to include('kind' => 'workout_analysis',
      'action_url' => workout_path(workout, analysis_id: analysis.id, anchor: 'ai-coaching'))
    expect(response.headers['Cache-Control']).to include('no-store')

    get status_notifications_path, as: :json
    expect(response.parsed_body).to include('unread_count' => 1, 'user_id' => user.id)
    expect(response.parsed_body['csrf_token']).to be_present
    expect(response.headers['Cache-Control']).to include('no-store')

    get notifications_path
    expect(response.body).to include(notification.title, 'data-action="click-&gt;notifications-center#open"')
    get notification.action_path
    expect(response.body).to include('data-coaching-live="false"', read_workout_workout_analysis_path(workout, analysis))
  end

  it 'clears only the reviewed analysis and supports marking every notification read' do
    first = complete_review
    newer = Ai::RequestWorkoutAnalysis.call(workout)
    AnalyseWorkoutJob.perform_now(newer.id)
    get status_notifications_path, as: :json
    expect(response.parsed_body['unread_count']).to eq(2)

    post read_workout_workout_analysis_path(workout, analysis), as: :json
    expect(response).to have_http_status(:ok)
    expect(first.reload).to be_read
    expect(newer.notification).not_to be_read
    get status_notifications_path, as: :json
    expect(response.parsed_body['unread_count']).to eq(1)

    patch mark_all_read_notifications_path, as: :json
    get status_notifications_path, as: :json
    expect(response.parsed_body['unread_count']).to eq(0)
  end

  it 'does not acknowledge a review simply because a background frame or page fetched it' do
    notification = complete_review
    get workout_path(workout)
    get workout_workout_analyses_path(workout)
    expect(notification.reload).not_to be_read
  end

  it 'does not allow another user to read the review or clear its notification' do
    notification = complete_review
    sign_in_as(users(:two))
    get status_notifications_path, as: :json
    expect(response.parsed_body['unread_count']).to eq(0)
    post read_workout_workout_analysis_path(workout, analysis), as: :json
    expect(response).to have_http_status(:not_found)
    patch read_notification_path(notification), as: :json
    expect(response).to have_http_status(:not_found)
    expect(notification.reload).not_to be_read
  end

  it 'returns an uncached 401 badge status after sign-out and removes the visibility lease' do
    post presence_notifications_path, params: { client_id: SecureRandom.uuid, sequence: 1, visible: true }
    expect(AppPresence.visible_for?(user)).to be(true)
    delete session_path
    get status_notifications_path, as: :json
    expect(response).to have_http_status(:unauthorized)
    expect(response.headers['Cache-Control']).to include('no-store')
    expect(AppPresence.visible_for?(user)).to be(false)
  end

  it 'tracks multiple windows independently and ignores late out-of-order heartbeats' do
    first, second = SecureRandom.uuid, SecureRandom.uuid
    post presence_notifications_path, params: { client_id: first, sequence: 1, visible: true }
    post presence_notifications_path, params: { client_id: second, sequence: 1, visible: true }
    post presence_notifications_path, params: { client_id: first, sequence: 3, visible: false }
    post presence_notifications_path, params: { client_id: first, sequence: 2, visible: true }
    expect(AppPresence.visible_for?(user)).to be(true)
    post presence_notifications_path, params: { client_id: second, sequence: 2, visible: false }
    expect(AppPresence.visible_for?(user)).to be(false)
    post presence_notifications_path, params: { client_id: first, sequence: 4, visible: true }
    travel 46.seconds do
      expect(AppPresence.visible_for?(user)).to be(false)
    end
  end

  it 'saves the AI push preference without disabling the notification feed' do
    patch settings_path, params: { user: { notify_ai_analysis_push: false } }
    expect(user.reload.notify_ai_analysis_push?).to be(false)
    complete_review
    get status_notifications_path, as: :json
    expect(response.parsed_body['unread_count']).to eq(1)
  end
end

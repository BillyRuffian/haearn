require 'rails_helper'

RSpec.describe 'AI notification delivery', type: :job do
  include_context 'AI coaching'
  include ActiveSupport::Testing::TimeHelpers
  let(:user) { users(:one) }
  let(:workout) { coaching_workout }
  let(:analysis) { workout.workout_analyses.sole }
  let(:delivery) { instance_double(WebPushNotificationService, deliver_notification: nil) }

  before do
    allow(responses_api).to receive(:create) { api_response(coaching_response(Ai::WorkoutContextBuilder.new(workout).call)) }
    allow(WebPushNotificationService).to receive(:new).with(user: user).and_return(delivery)
  end

  def complete_review
    AnalyseWorkoutJob.perform_now(analysis.id)
    analysis.reload.notification
  end

  it 'records and pushes one notification when analysis completes away from the app, even on job replay' do
    notification = complete_review
    expect(notification).to be_present
    expect { AnalyseWorkoutJob.perform_now(analysis.id) }.not_to change(Notification, :count)
    expect(AiAnalysisNotificationService.record!(analysis.reload)).to eq(notification)
    2.times { DeliverAnalysisNotificationJob.perform_now(notification.id) }
    expect(delivery).to have_received(:deliver_notification).with(notification).once
    expect(notification.reload.push_processed_at).to be_present
  end

  it 'keeps an in-app notification but suppresses push when any window was visible at completion' do
    session = user.sessions.create!
    AppPresence.report!(session: session, client_id: SecureRandom.uuid, sequence: 1, visible: true)
    notification = complete_review
    expect(notification).not_to be_read
    AppPresence.delete_all
    DeliverAnalysisNotificationJob.perform_now(notification.id)
    expect(delivery).not_to have_received(:deliver_notification)
  end

  it 'rechecks read status before sending a queued push' do
    notification = complete_review
    notification.mark_read!
    DeliverAnalysisNotificationJob.perform_now(notification.id)
    expect(delivery).not_to have_received(:deliver_notification)
  end

  it 'suppresses a queued push if the user returns before delivery' do
    notification = complete_review
    AppPresence.report!(session: user.sessions.create!, client_id: SecureRandom.uuid, sequence: 1, visible: true)
    DeliverAnalysisNotificationJob.perform_now(notification.id)
    expect(delivery).not_to have_received(:deliver_notification)
  end

  it 'does not suppress an away push for an expired visibility lease' do
    session = user.sessions.create!
    AppPresence.report!(session: session, client_id: SecureRandom.uuid, sequence: 1, visible: true)
    travel 46.seconds do
      notification = complete_review
      DeliverAnalysisNotificationJob.perform_now(notification.id)
      expect(delivery).to have_received(:deliver_notification).once
    end
  end

  it 'does not notify for failed results' do
    allow(responses_api).to receive(:create).and_return(api_response(nil, content: [ { type: 'refusal', refusal: 'No' } ]))
    expect(complete_review).to be_nil
    expect(analysis.reload).to be_failed
  end

  it 'does not publish a result from a superseded worker' do
    allow(responses_api).to receive(:create) do
      analysis.update_columns(status: 'failed', processing_token: nil)
      api_response(coaching_response(Ai::WorkoutContextBuilder.new(workout).call))
    end
    expect(complete_review).to be_nil
  end

  it 'does not push an old completion if the workout was continued' do
    notification = complete_review
    workout.update!(finished_at: nil)
    DeliverAnalysisNotificationJob.perform_now(notification.id)
    expect(delivery).not_to have_received(:deliver_notification)
  end

  it 'recovers a lost delivery enqueue without duplicating analysis or notification records' do
    notification = complete_review
    notification.update_columns(created_at: 2.minutes.ago)
    clear_enqueued_jobs
    expect { RecoverAnalysisNotificationsJob.perform_now }.to have_enqueued_job(DeliverAnalysisNotificationJob).with(notification.id)
    DeliverAnalysisNotificationJob.perform_now(notification.id)
    clear_enqueued_jobs
    expect { RecoverAnalysisNotificationsJob.perform_now }.not_to have_enqueued_job(DeliverAnalysisNotificationJob)
  end

  it 'preserves the completed review and unread notification if enqueue fails' do
    analysis
    allow(DeliverAnalysisNotificationJob).to receive(:perform_later).and_raise(ActiveJob::EnqueueError)
    notification = complete_review
    expect(analysis.reload).to be_completed
    expect(notification).not_to be_read
    expect(notification.push_processed_at).to be_nil
  end
end

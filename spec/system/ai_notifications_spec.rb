require 'rails_helper'

RSpec.describe 'AI review notifications', type: :system, js: true do
  self.use_transactional_tests = false
  include_context 'AI coaching'
  let(:user) { users(:system) }

  before do
    user.workouts.in_progress.update_all(finished_at: Time.current)
    sign_in_via_ui(user)
  end

  after do
    user.workouts.where.not(id: [ workouts(:active_logging).id, workouts(:previous_logging).id ]).destroy_all
    AppPresence.joins(:session).where(sessions: { user_id: user.id }).delete_all
  end

  def wait_for_database
    Timeout.timeout(10) { sleep 0.05 until yield }
  end

  def complete_review(workout)
    allow(responses_api).to receive(:create) { api_response(coaching_response(Ai::WorkoutContextBuilder.new(workout).call)) }
    AnalyseWorkoutJob.perform_now(workout.workout_analyses.sole.id)
    workout.workout_analyses.sole.notification
  end

  it 'suppresses foreground push and opens the exact review from the notification center' do
    workout = coaching_workout(user: user, exercise: exercises(:system_press))
    visit root_path
    wait_for_database { AppPresence.visible_for?(user) }
    notification = complete_review(workout)
    expect(notification.push_processed_at).to be_present
    expect(notification).not_to be_read
    visit notifications_path
    click_link 'Your AI workout review is ready'
    expect(page).to have_current_path(notification.action_path.split('#').first, ignore_query: false)
    expect(page.evaluate_script('location.hash')).to eq('#ai-coaching')
    expect(page).to have_css('#ai-coaching[data-coaching-live="false"]')
    wait_for_database { notification.reload.read? }
  end

  it 'pushes a hidden-tab completion and acknowledges the review only after it becomes visible' do
    workout = coaching_workout(user: user, exercise: exercises(:system_press))
    visit workout_path(workout)
    expect(page).to have_css('turbo-cable-stream-source[connected]', visible: :all)
    expect(page).to have_no_css('turbo-frame[busy]', visible: :all)
    wait_for_database { AppPresence.visible_for?(user) }
    page.execute_script(<<~JS)
      Object.defineProperty(document, 'hidden', { configurable: true, value: true })
      document.dispatchEvent(new Event('visibilitychange'))
      window.badgeRefreshRequests = 0
      const originalPostMessage = ServiceWorker.prototype.postMessage
      ServiceWorker.prototype.postMessage = function(message, ...args) {
        if (message?.type === 'REFRESH_NOTIFICATION_BADGE') window.badgeRefreshRequests++
        return originalPostMessage.call(this, message, ...args)
      }
    JS
    wait_for_database { !AppPresence.visible_for?(user) }
    notification = complete_review(workout)
    expect(notification.push_processed_at).to be_nil
    delivery = instance_double(WebPushNotificationService, deliver_notification: nil)
    allow(WebPushNotificationService).to receive(:new).with(user: user).and_return(delivery)
    DeliverAnalysisNotificationJob.perform_now(notification.id)
    expect(delivery).to have_received(:deliver_notification).with(notification)
    expect(notification.reload).not_to be_read
    page.execute_script(<<~JS)
      delete document.hidden
      document.dispatchEvent(new Event('visibilitychange'))
    JS
    within('#ai-coaching') { expect(page).to have_text('You added useful reps.') }
    page.execute_script("arguments[0].scrollIntoView({ block: 'center', behavior: 'instant' })", find('#ai-coaching'))
    wait_for_database { notification.reload.read? }
    expect(page.evaluate_script('window.badgeRefreshRequests')).to be > 0
  end
end

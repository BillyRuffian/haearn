require 'rails_helper'

RSpec.describe 'Offline sync confidence', type: :system, js: true do
  let(:user) { users(:system) }
  let(:workout) { workouts(:active_logging) }
  let(:workout_exercise) { workout_exercises(:active_logging) }

  before do
    sign_in_via_ui(user)
    reset_offline_storage
  end

  after do
    reset_offline_storage
  end

  it 'shows queued state and exposes retry when sync fails' do
    visit root_path

    seed_offline_pending_item(
      "id" => 1,
      "url" => workouts_path,
      "method" => "POST",
      "data" => { "example" => "payload" },
      "requestId" => "offline-confidence-test"
    )

    page.execute_script("document.body.dispatchEvent(new CustomEvent('offline-form:queued', { bubbles: true }))")

    within("[data-offline-target='confidence']", visible: true) do
      expect(page).to have_css("[data-offline-target='queueCount']", text: '1', visible: true)
      expect(page).to have_css("[data-offline-target='status']", text: /\AQueued\z/i, visible: :visible)
      expect(page).to have_button('Sync now', exact: false)
    end

    page.execute_script(<<~JS)
      window.__haearnOriginalFetch = window.fetch.bind(window)
      window.fetch = (url, options = {}) => {
        if ((options.method || "GET").toUpperCase() !== "GET") {
          return Promise.reject(new Error("forced sync failure"))
        }

        return window.__haearnOriginalFetch(url, options)
      }
    JS

    within("[data-offline-target='confidence']", visible: true) do
      click_button 'Sync now'
      expect(page).to have_css("[data-offline-target='status']", text: /\ASync failed\z/i, visible: :visible)
      expect(page).to have_button('Retry', exact: false)
      expect(page).to have_css("[data-offline-target='queueCount']", text: '1', visible: true)
    end
  end

  it 'queues consecutive sets offline and replays each set once after reconnecting' do
    page.current_window.resize_to(390, 844)
    visit workout_path(workout)
    starting_count = workout_exercise.exercise_sets.count

    page.execute_script(<<~JS)
      Object.defineProperty(window.navigator, "onLine", { configurable: true, get: () => false })
      window.dispatchEvent(new Event("offline"))
    JS

    within("##{ActionView::RecordIdentifier.dom_id(workout_exercise)}") do
      click_button 'Add Set'
      find("input[name='exercise_set[weight_value]']").set('52.5')
      find("input[name='exercise_set[reps]']").set('10')
      click_button 'Log set'
      expect(page).to have_css('.offline-pending-set', count: 1)

      click_button 'Add Set'
      find("input[name='exercise_set[reps]']").set('8')
      click_button 'Log set'
      expect(page).to have_css('.offline-pending-set', count: 2)
    end

    expect(workout_exercise.exercise_sets.reload.count).to eq(starting_count)
    expect(page).to have_css("[data-offline-target='queueCount']", text: '2', visible: true)

    page.execute_script(<<~JS)
      Object.defineProperty(window.navigator, "onLine", { configurable: true, get: () => true })
      window.dispatchEvent(new Event("online"))
    JS

    expect(page).to have_no_css('.offline-pending-set', wait: 10)
    expect(workout_exercise.exercise_sets.reload.count).to eq(starting_count + 2)
    expect(workout_exercise.exercise_sets.order(:id).last(2).map(&:reps)).to eq([ 10, 8 ])
  end

  it 'queues workout completion offline and finishes after reconnecting' do
    visit workout_path(workout)

    page.execute_script(<<~JS)
      Object.defineProperty(window.navigator, "onLine", { configurable: true, get: () => false })
      window.dispatchEvent(new Event("offline"))
    JS

    accept_confirm('Finish this workout?') { click_button 'Finish' }
    expect(page).to have_button('Finish queued', disabled: true)
    expect(workout.reload).to be_in_progress
    expect(page).to have_css("[data-offline-target='queueCount']", text: '1', visible: true)

    page.execute_script(<<~JS)
      Object.defineProperty(window.navigator, "onLine", { configurable: true, get: () => true })
      window.dispatchEvent(new Event("online"))
    JS

    expect(page).to have_no_button('Finish queued', wait: 10)
    expect(page).to have_button('Continue')
    expect(workout.reload.finished_at).to be_present
  end
end

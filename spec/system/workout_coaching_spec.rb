require 'rails_helper'

RSpec.describe 'Workout coaching panel', type: :system, js: true do
  # Cable's connection and post-commit broadcasts must see genuinely committed rows.
  self.use_transactional_tests = false
  include_context 'AI coaching'
  let(:user) { users(:system) }

  before do
    user.workouts.in_progress.update_all(finished_at: Time.current)
    sign_in_via_ui(user)
  end

  after do
    user.workouts.where.not(id: [ workouts(:active_logging).id, workouts(:previous_logging).id ]).destroy_all
  end

  it 'refreshes completed coaching, fits phone/desktop screens, and offers a traceable retry' do
    workout = coaching_workout(user: user, exercise: exercises(:system_press))
    analysis = workout.workout_analyses.sole
    data = coaching_response(Ai::WorkoutContextBuilder.new(workout).call)
    allow(responses_api).to receive(:create).and_return(api_response(data))
    page.current_window.resize_to(390, 844)
    visit workout_path(workout)
    expect(page).to have_text('Coaching queued.')
    expect(page).to have_css('turbo-cable-stream-source[connected]', visible: :all)
    expect(page).to have_no_css('turbo-frame[busy]', visible: :all)
    expect(page).to have_css('#ai-coaching [role="status"] .coaching-pending-spinner')
    # Observe a full former polling interval while the review remains pending.
    requests = Capybara.using_wait_time(10) do
      page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      let requests = 0
      const observe = event => {
        if (event.target.id?.startsWith('coaching_workout_')) requests++
      }
      document.addEventListener('turbo:before-fetch-request', observe)
      setTimeout(() => {
        document.removeEventListener('turbo:before-fetch-request', observe)
        done(requests)
      }, 6200)
    JS
    end
    expect(requests).to eq(0)
    page.execute_script("arguments[0].scrollIntoView({ block: 'center', behavior: 'instant' })", find('#ai-coaching'))
    page.save_screenshot(Rails.root.join('tmp/ai-coaching-pending.png'))
    page.driver.browser.execute_cdp('Emulation.setEmulatedMedia', features: [ { name: 'prefers-reduced-motion', value: 'reduce' } ])
    expect(page.evaluate_script("getComputedStyle(document.querySelector('.coaching-pending-spinner')).animationName")).to eq('none')
    page.driver.browser.execute_cdp('Emulation.setEmulatedMedia', features: [])
    # Prove websocket delivery without document navigation or periodic polling.
    page.execute_script(<<~JS)
      window.coachingDocument = 'original-document'
      window.coachingPushes = 0
      document.addEventListener('turbo:before-stream-render', () => window.coachingPushes++)
    JS

    AnalyseWorkoutJob.perform_now(analysis.id)
    within('#ai-coaching') do
      expect(page).to have_text(data.dig('overall', 'summary'), wait: 10)
      expect(page).to have_text('Next session')
      expect(page).to have_text('37.5 kg')
      expect(page).to have_no_css('.spinner-border')
    end
    expect(page.evaluate_script('window.coachingPushes')).to be >= 1
    expect(page.evaluate_script('window.coachingDocument')).to eq('original-document')
    [ [ 390, 844 ], [ 1440, 1000 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      dimensions = page.evaluate_script(<<~JS)
        (() => {
          const panel = document.querySelector('#ai-coaching')
          return { right: panel.getBoundingClientRect().right, width: window.innerWidth,
            content: panel.scrollWidth, available: panel.clientWidth }
        })()
      JS
      expect(dimensions['right']).to be <= dimensions['width']
      expect(dimensions['content']).to be <= dimensions['available'] + 1
      page.execute_script("window.scrollTo({ top: arguments[0].getBoundingClientRect().top + window.scrollY - 85, behavior: 'instant' })", find('#ai-coaching'))
      page.save_screenshot(Rails.root.join("tmp/ai-coaching-#{width}.png"))
    end

    within('#ai-coaching') { click_button 'Reanalyse workout' }
    expect(page).to have_text('AI coaching queued.')
    latest = workout.workout_analyses.newest_first.first
    expect(latest.id).not_to eq(analysis.id)
    latest.fail_safely!('test_failure')
    within('#ai-coaching') do
      expect(page).to have_button('Retry coaching', wait: 10)
      expect(page).not_to have_text('test_failure')
      click_button 'Retry coaching'
    end
    expect(page).to have_text('AI coaching queued.')
    expect(workout.workout_analyses.count).to eq(3)
    expect(analysis.reload).to be_completed
  end

  it 'keeps a selected historical analysis visible when a newer analysis finishes' do
    workout = coaching_workout(user: user, exercise: exercises(:system_press))
    first = workout.workout_analyses.sole
    data = coaching_response(Ai::WorkoutContextBuilder.new(workout).call)
    allow(responses_api).to receive(:create).and_return(api_response(data))
    AnalyseWorkoutJob.perform_now(first.id)
    latest = Ai::RequestWorkoutAnalysis.call(workout)
    visit workout_path(workout)
    expect(page).to have_css('turbo-cable-stream-source[connected]', visible: :all)
    within('#ai-coaching') do
      find('summary').click
      click_link(href: workout_workout_analysis_path(workout, first))
      expect(page).to have_text(data.dig('overall', 'summary'))
    end
    expect(page).to have_css('#ai-coaching[data-coaching-live="false"]')
    latest.fail_safely!('test_failure')
    # The pushed signal is processed, but it must not replace a deliberately selected version.
    page.execute_script("document.querySelector('[data-coaching-refresh-target=signal]').dataset.oldSignal = 'true'")
    WorkoutAnalysis.broadcast_coaching_change_for(workout.id)
    expect(page).to have_no_css('[data-old-signal]', visible: :all)
    within('#ai-coaching') do
      expect(page).to have_text(data.dig('overall', 'summary'))
      click_link 'Refresh'
      expect(page).to have_button('Retry coaching')
    end
  end

  it 'catches up after a stream reconnects even when the completion push was missed' do
    workout = coaching_workout(user: user, exercise: exercises(:system_press))
    analysis = workout.workout_analyses.sole
    visit workout_path(workout)
    expect(page).to have_css('turbo-cable-stream-source[connected]', visible: :all)
    expect(page).to have_no_css('turbo-frame[busy]', visible: :all)
    page.execute_script(<<~JS)
      const element = document.querySelector('[data-controller="coaching-refresh"]')
      window.coachingSource = element.querySelector('turbo-cable-stream-source')
      window.coachingSource.remove()
    JS
    expect(page).to have_no_css('turbo-cable-stream-source', visible: :all)
    data = coaching_response(Ai::WorkoutContextBuilder.new(workout).call)
    allow(responses_api).to receive(:create).and_return(api_response(data))
    AnalyseWorkoutJob.perform_now(analysis.id)
    expect(page).to have_text('Coaching queued.')
    page.execute_script("document.querySelector('[data-controller=coaching-refresh]').prepend(window.coachingSource)")
    expect(page).to have_css('turbo-cable-stream-source[connected]', visible: :all)
    within('#ai-coaching') { expect(page).to have_text(data.dig('overall', 'summary')) }
  end
end

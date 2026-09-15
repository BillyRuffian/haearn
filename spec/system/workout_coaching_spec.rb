require 'rails_helper'

RSpec.describe 'Workout coaching panel', type: :system, js: true do
  include_context 'AI coaching'
  let(:user) { users(:system) }

  before do
    user.workouts.in_progress.update_all(finished_at: Time.current)
    sign_in_via_ui(user)
  end

  it 'refreshes completed coaching, fits phone/desktop screens, and offers a traceable retry' do
    workout = coaching_workout(user: user, exercise: exercises(:system_press))
    analysis = workout.workout_analyses.sole
    data = coaching_response(Ai::WorkoutContextBuilder.new(workout).call)
    allow(responses_api).to receive(:create).and_return(api_response(data))
    page.current_window.resize_to(390, 844)
    visit workout_path(workout)
    expect(page).to have_text('Coaching queued.')

    AnalyseWorkoutJob.perform_now(analysis.id)
    within('#ai-coaching') do
      expect(page).to have_text(data.dig('overall', 'summary'), wait: 10)
      expect(page).to have_text('Next session')
      expect(page).to have_text('37.5 kg')
    end
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
end

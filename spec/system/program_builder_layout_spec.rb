require 'rails_helper'

RSpec.describe 'Program builder layout', type: :system, js: true do
  let(:user) { users(:system) }
  let(:workout_template) do
    template = user.workout_templates.create!(name: 'System Strength')
    block = template.template_blocks.create!(position: 1)
    block.template_exercises.create!(
      exercise: exercises(:system_press),
      target_sets: 4,
      target_reps: 6,
      target_weight_kg: 45
    )
    template
  end
  let(:training_program) do
    program = user.training_programs.create!(name: 'System Mesocycle', weeks_count: 4)
    program.program_sessions.create!(
      workout_template: workout_template,
      name: 'Press Session',
      week_number: 1,
      weekday: Date.current.cwday,
      volume_percent: 75,
      intensity_percent: 90
    )
    program.activate!(starts_on: Date.current.beginning_of_week)
    program
  end

  before do
    user.workouts.in_progress.update_all(finished_at: 1.minute.ago)
    training_program
    sign_in_via_ui(user)
  end

  it 'contains the week grid and daily prescription at desktop and phone widths' do
    page.current_window.resize_to(1440, 1000)
    visit training_program_path(training_program)

    expect(page).to have_css('h1.display-heading')
    expect(page).to have_text('SYSTEM MESOCYCLE')
    expect(page).to have_css('.program-week-grid', count: 4)
    expect_page_within_viewport
    page.save_screenshot(Rails.root.join('tmp/program-builder-desktop.png').to_s) if ENV['CAPTURE_PROGRAM'] == '1'

    page.current_window.resize_to(390, 844)
    visit training_program_path(training_program)

    expect_page_within_viewport
    grid = page.evaluate_script(<<~JS)
      (() => {
        const week = document.querySelector('.program-week')
        const rect = week.getBoundingClientRect()
        return {
          right: rect.right,
          viewport: window.innerWidth,
          scrollWidth: week.scrollWidth,
          clientWidth: week.clientWidth
        }
      })()
    JS
    expect(grid['right']).to be <= grid['viewport'] + 1
    expect(grid['scrollWidth']).to be > grid['clientWidth']
    page.save_screenshot(Rails.root.join('tmp/program-builder-mobile.png').to_s) if ENV['CAPTURE_PROGRAM'] == '1'

    visit today_session_path

    expect(page).to have_css('h1.display-heading')
    expect(page).to have_text('TODAY’S SESSION')
    expect(page).to have_text('PRESS SESSION')
    expect_page_within_viewport
    page.save_screenshot(Rails.root.join('tmp/todays-session-mobile.png').to_s) if ENV['CAPTURE_PROGRAM'] == '1'
  end

  def expect_page_within_viewport
    dimensions = page.evaluate_script(<<~JS)
      ({
        viewport: window.innerWidth,
        bodyWidth: document.body.scrollWidth,
        documentWidth: document.documentElement.scrollWidth,
        offenders: Array.from(document.querySelectorAll('body *')).filter((element) => {
          const rect = element.getBoundingClientRect()
          const style = window.getComputedStyle(element)
          return rect.right > window.innerWidth + 1 && style.position !== 'fixed'
        }).slice(0, 8).map((element) => ({
          tag: element.tagName,
          className: element.className,
          right: Math.round(element.getBoundingClientRect().right),
          width: Math.round(element.getBoundingClientRect().width)
        }))
      })
    JS

    expect(dimensions['bodyWidth']).to be <= dimensions['viewport'] + 1, dimensions['offenders'].inspect
    expect(dimensions['documentWidth']).to be <= dimensions['viewport'] + 1
  end
end

require 'rails_helper'

RSpec.describe 'Analytics responsive layout', type: :system, js: true do
  let(:user) { users(:system) }
  let(:gym) { gyms(:system) }

  before do
    user.workouts.in_progress.update_all(finished_at: 2.hours.ago)
    exercise = user.exercises.create!(
      name: 'Responsive Analytics Press',
      exercise_type: 'reps',
      has_weight: true,
      primary_muscle_group: 'chest'
    )
    machine = gym.machines.create!(name: 'Responsive Stack', equipment_type: 'machine', display_unit: 'kg')
    workout = user.workouts.create!(gym: gym, started_at: 2.days.ago, finished_at: 2.days.ago + 1.hour)

    [ machine, nil ].each_with_index do |context_machine, context_index|
      block = workout.workout_blocks.create!(position: context_index + 1, rest_seconds: 90)
      workout_exercise = block.workout_exercises.create!(exercise: exercise, machine: context_machine, position: 1)
      [ 3, 8, 12 ].each_with_index do |reps, set_index|
        workout_exercise.exercise_sets.create!(
          position: set_index + 1,
          reps: reps,
          weight_kg: 40 + context_index * 5 + set_index,
          is_warmup: false,
          completed_at: workout.started_at + (context_index * 10 + set_index + 1).minutes
        )
      end
    end

    sign_in_via_ui(user)
    visit analytics_path
    expect(page).to have_css('.analytics-page canvas', minimum: 1)
  end

  it 'keeps charts and page content within phone, tablet, and desktop viewports while resizing' do
    [ [ 320, 844 ], [ 390, 844 ], [ 768, 1024 ], [ 1440, 1000 ], [ 320, 844 ], [ 1440, 1000 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      expect(page).to have_css('.analytics-page')
      expect_analytics_geometry
    end
  end

  it 'updates chart controls and contains wide tables on a phone' do
    page.current_window.resize_to(390, 844)

    find('#muscle-volume-period').select('Last 30 calendar days')
    strength_select = find('#strength-curve-context')
    expect(strength_select.all('option').length).to be >= 2
    strength_select.select(strength_select.all('option').last.text)

    expect(page).to have_css('.analytics-table-wrap', minimum: 1)
    table_geometry = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('.analytics-table-wrap')).map((wrapper) => {
        const rect = wrapper.getBoundingClientRect()
        return {
          left: rect.left,
          right: rect.right,
          viewport: window.innerWidth,
          scrollWidth: wrapper.scrollWidth,
          clientWidth: wrapper.clientWidth
        }
      })
    JS

    table_geometry.each do |table|
      expect(table['left']).to be >= -1
      expect(table['right']).to be <= table['viewport'] + 1
      expect(table['clientWidth']).to be > 0
    end
    expect_analytics_geometry
  end

  def expect_analytics_geometry
    geometry = page.evaluate_script(<<~JS)
      (() => {
        const viewport = window.innerWidth
        return {
          viewport,
          bodyWidth: document.body.scrollWidth,
          documentWidth: document.documentElement.scrollWidth,
          charts: Array.from(document.querySelectorAll('.analytics-chart')).map((chart) => {
            const rect = chart.getBoundingClientRect()
            const canvas = chart.querySelector('canvas')
            const canvasRect = canvas?.getBoundingClientRect()
            return {
              left: rect.left,
              right: rect.right,
              width: rect.width,
              height: rect.height,
              canvasWidth: canvasRect?.width || 0,
              canvasHeight: canvasRect?.height || 0
            }
          })
        }
      })()
    JS

    expect(geometry['bodyWidth']).to be <= geometry['viewport'] + 1
    expect(geometry['documentWidth']).to be <= geometry['viewport'] + 1
    expect(geometry['charts']).not_to be_empty
    geometry['charts'].each do |chart|
      expect(chart['left']).to be >= -1
      expect(chart['right']).to be <= geometry['viewport'] + 1
      expect(chart['width']).to be > 0
      expect(chart['height']).to be > 0
      expect(chart['canvasWidth']).to be > 0
      expect(chart['canvasHeight']).to be > 0
    end
  end
end

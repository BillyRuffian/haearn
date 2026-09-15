require 'rails_helper'

RSpec.describe 'Stored template editing', type: :system, js: true do
  let(:user) { users(:system) }
  let!(:template) { user.workout_templates.create!(name: 'Stored Strength') }
  let!(:template_block) { template.template_blocks.create!(position: 1) }
  let!(:template_exercise) do
    template_block.template_exercises.create!(exercise: exercises(:system_press), target_sets: 3, target_reps: 8)
  end
  let!(:historical_exercise) do
    workout = user.workouts.create!(gym: gyms(:system), started_at: 2.days.ago, finished_at: 2.days.ago + 1.hour)
    block = workout.workout_blocks.create!(position: 1)
    block.workout_exercises.create!(exercise: template_exercise.exercise, template_exercise: template_exercise)
  end

  before do
    sign_in_via_ui(user)
    page.current_window.resize_to(390, 844)
  end

  it 'updates an exercise, cancels removal, then removes and restores it without losing history' do
    visit edit_workout_template_template_exercise_path(template, template_exercise)
    fill_in 'Sets', with: 5
    click_button 'Update Exercise'

    expect(page).to have_current_path(workout_template_path(template))
    expect(page).to have_text('Exercise updated.')
    expect(template_exercise.reload.target_sets).to eq(5)
    expect(template_exercise.removed_at).to be_nil

    visit edit_workout_template_template_exercise_path(template, template_exercise)
    dismiss_confirm('Remove this exercise from the template?') { click_button 'Delete' }
    expect(page).to have_current_path(edit_workout_template_template_exercise_path(template, template_exercise))
    expect(template_exercise.reload.removed_at).to be_nil

    # Removing a stored exercise must not submit unsaved, invalid target edits.
    fill_in 'Sets', with: 0
    accept_confirm('Remove this exercise from the template?') { click_button 'Delete' }

    expect(page).to have_current_path(workout_template_path(template))
    expect(page).to have_text('Exercise removed from template.')
    expect(page).to have_text(/Archived Exercises/i)
    expect(template_exercise.reload.removed_at).to be_present
    expect(template_exercise.target_sets).to eq(5)
    expect(template.reload.template_exercises).to be_empty
    expect(historical_exercise.reload.template_exercise).to eq(template_exercise)

    accept_confirm('Restore this exercise to the template?') { click_button 'Restore' }
    expect(page).to have_text('Exercise restored to template.')
    expect(template_exercise.reload.removed_at).to be_nil
    expect(historical_exercise.reload.template_exercise).to eq(template_exercise)
  end

  it 'updates template details and deletes an unused template from its edit page' do
    unused_template = user.workout_templates.create!(name: 'Unused Template')
    visit edit_workout_template_path(unused_template)
    fill_in 'Name', with: 'Renamed Template'
    click_button 'Update Template'

    expect(page).to have_current_path(workout_template_path(unused_template))
    expect(page).to have_text('Template updated successfully.')
    expect(unused_template.reload.name).to eq('Renamed Template')

    visit edit_workout_template_path(unused_template)
    accept_confirm('Delete this template? This cannot be undone.') { click_button 'Delete' }

    expect(page).to have_current_path(workout_templates_path)
    expect(page).to have_text('Template deleted successfully.')
    expect(WorkoutTemplate.exists?(unused_template.id)).to be(false)
  end
end

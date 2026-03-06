require 'rails_helper'

RSpec.describe 'Workout set lifecycle', type: :system, js: true do
  let(:user) { users(:system) }
  let(:workout) { workouts(:active_logging) }
  let(:workout_exercise) { workout_exercises(:active_logging) }
  let(:exercise_set) { exercise_sets(:active_logging_first_set) }

  before do
    sign_in_via_ui(user)
  end

  it 'duplicates a set and supports inline edit save and cancel flows' do
    visit workout_path(workout)

    within("##{ActionView::RecordIdentifier.dom_id(workout_exercise)}") do
      expect(page).to have_css(".set-row", count: 1)
    end

    within("turbo-frame##{ActionView::RecordIdentifier.dom_id(exercise_set)}") do
      find("button[data-bs-toggle='dropdown']").click
      click_button 'Duplicate'
    end

    within("##{ActionView::RecordIdentifier.dom_id(workout_exercise)}") do
      expect(page).to have_css(".set-row", count: 2)
      expect(page).to have_text('42.5', count: 2)
      expect(page).to have_text('9', count: 2)
    end

    within("turbo-frame##{ActionView::RecordIdentifier.dom_id(exercise_set)}") do
      find("button[data-bs-toggle='dropdown']").click
      click_link 'Edit'
    end

    within("##{ActionView::RecordIdentifier.dom_id(workout_exercise)}") do
      expect(page).to have_css('form.edit-set-form')
      within('form.edit-set-form') do
        find("input[name='exercise_set[reps]']", visible: :all).set('10')
      end
      click_button 'Save'

      expect(page).to have_no_css('form.edit-set-form')
      expect(page).to have_text('10')
    end

    within("turbo-frame##{ActionView::RecordIdentifier.dom_id(exercise_set)}") do
      find("button[data-bs-toggle='dropdown']").click
      click_link 'Edit'
    end

    within("##{ActionView::RecordIdentifier.dom_id(workout_exercise)}") do
      expect(page).to have_css('form.edit-set-form')
      within('form.edit-set-form') do
        find("input[name='exercise_set[reps]']", visible: :all).set('12')
      end
      click_link 'Cancel'

      expect(page).to have_no_css('form.edit-set-form')
    end

    within("turbo-frame##{ActionView::RecordIdentifier.dom_id(exercise_set)}") do
      expect(page).to have_text('10')
      expect(page).to have_no_text('12')
    end
  end
end

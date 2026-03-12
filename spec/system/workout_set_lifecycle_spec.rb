require 'rails_helper'

RSpec.describe 'Workout set lifecycle', type: :system, js: true do
  let(:user) { users(:system) }
  let(:workout) { workouts(:active_logging) }
  let(:workout_exercise) { workout_exercises(:active_logging) }
  let(:exercise_set) { exercise_sets(:active_logging_first_set) }

  before do
    sign_in_via_ui(user)
  end

  def duplicate_set(path)
    page.execute_script(<<~JS, path)
      const form = document.querySelector(`form[action="${arguments[0]}"]`)
      if (!form) throw new Error(`Missing duplicate form for path: ${arguments[0]}`)
      if (form.requestSubmit) {
        form.requestSubmit()
      } else {
        form.submit()
      }
    JS
  end

  def open_inline_edit(edit_path, frame_id)
    page.execute_script(<<~JS, edit_path, frame_id)
      if (!window.Turbo) throw new Error("Turbo is unavailable")
      window.Turbo.visit(arguments[0], { frame: arguments[1] })
    JS
  end

  it 'duplicates a set and supports inline edit save and cancel flows' do
    visit workout_path(workout)

    within("##{ActionView::RecordIdentifier.dom_id(workout_exercise)}") do
      expect(page).to have_css(".set-row", count: 1)
    end

    duplicate_set(duplicate_workout_workout_exercise_exercise_set_path(workout, workout_exercise, exercise_set))

    within("##{ActionView::RecordIdentifier.dom_id(workout_exercise)}") do
      expect(page).to have_css(".set-row", count: 2)
      reps = all(".set-row .reps-display").map(&:text)
      weights = all(".set-row .weight-display").map { |node| node.text.squish }

      expect(reps).to eq(%w[9 9])
      expect(weights).to all(include("42.5"))
    end

    open_inline_edit(
      edit_workout_workout_exercise_exercise_set_path(workout, workout_exercise, exercise_set),
      ActionView::RecordIdentifier.dom_id(exercise_set)
    )

    within("##{ActionView::RecordIdentifier.dom_id(workout_exercise)}") do
      expect(page).to have_css('form.edit-set-form')
      within('form.edit-set-form') do
        find("input[name='exercise_set[reps]']", visible: :all).set('10')
      end
      click_button 'Save'

      expect(page).to have_no_css('form.edit-set-form')
      expect(page).to have_text('10')
    end

    open_inline_edit(
      edit_workout_workout_exercise_exercise_set_path(workout, workout_exercise, exercise_set),
      ActionView::RecordIdentifier.dom_id(exercise_set)
    )

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

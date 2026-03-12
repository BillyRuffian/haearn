require 'rails_helper'

RSpec.describe 'Workout set visibility', type: :system, js: true do
  let(:user) { users(:system) }
  let(:workout) { workouts(:active_logging) }
  let(:workout_exercise) { workout_exercises(:active_logging) }
  let(:exercise_set) { exercise_sets(:active_logging_first_set) }

  before do
    sign_in_via_ui(user)
  end

  def open_inline_edit(edit_path, frame_id)
    page.execute_script(<<~JS, edit_path, frame_id)
      if (!window.Turbo) throw new Error("Turbo is unavailable")
      window.Turbo.visit(arguments[0], { frame: arguments[1] })
    JS
  end

  it 'hides the add-set trigger when the add form is open and when editing a set' do
    visit workout_path(workout)

    within("##{ActionView::RecordIdentifier.dom_id(workout_exercise)}") do
      expect(page).to have_button('Add Set')
      click_button 'Add Set'
      expect(page).to have_css('form.add-set-form')
      expect(page).to have_no_button('Add Set')
    end

    visit workout_path(workout)

    open_inline_edit(
      edit_workout_workout_exercise_exercise_set_path(workout, workout_exercise, exercise_set),
      ActionView::RecordIdentifier.dom_id(exercise_set)
    )

    within("##{ActionView::RecordIdentifier.dom_id(workout_exercise)}") do
      expect(page).to have_css('form.edit-set-form')
    end

    add_set_button_hidden = page.evaluate_script(<<~JS, ActionView::RecordIdentifier.dom_id(workout_exercise))
      (() => {
        const exercise = document.getElementById(arguments[0])
        const button = exercise?.querySelector("[data-add-set-toggle-target='button']")
        if (!button) return false

        const style = window.getComputedStyle(button)
        return button.hidden || style.display === "none" || style.visibility === "hidden"
      })()
    JS

    expect(add_set_button_hidden).to be(true)
  end

  it 'copies extended previous-session fields when using the Last button' do
    visit workout_path(workout)

    within("##{ActionView::RecordIdentifier.dom_id(workout_exercise)}") do
      click_button 'Add Set'
      expect(page).to have_css("[data-copy-last-payload-value]")
      click_button 'Last'

      expect(find("input[name='exercise_set[weight_value]']", visible: :all).value).to eq('47.5')
      expect(find("input[name='exercise_set[reps]']", visible: :all).value).to eq('12')
      expect(find("input[type='checkbox'][name='exercise_set[is_warmup]']", visible: :all)).not_to be_checked
      expect(find("input[type='checkbox'][name='exercise_set[is_amrap]']", visible: :all)).to be_checked
      expect(find("select[name='exercise_set[set_type]']", visible: :all).value).to eq('backoff')
      expect(find("input[type='checkbox'][name='exercise_set[belt]']", visible: :all)).to be_checked
      expect(find("input[type='checkbox'][name='exercise_set[pain_flag]']", visible: :all)).to be_checked
    end
  end
end

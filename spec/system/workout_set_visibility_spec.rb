require 'rails_helper'

RSpec.describe 'Workout set visibility', type: :system, js: true do
  let(:user) { users(:system) }
  let(:workout) { workouts(:active_logging) }
  let(:workout_exercise) { workout_exercises(:active_logging) }
  let(:exercise_set) { exercise_sets(:active_logging_first_set) }

  before do
    sign_in_via_ui(user)
  end

  def click_set_edit_action(selector)
    page.execute_script(<<~JS, selector)
      const action = document.querySelector(arguments[0])
      if (!action) throw new Error(`Missing action for selector: ${arguments[0]}`)
      action.click()
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

    click_set_edit_action("turbo-frame##{ActionView::RecordIdentifier.dom_id(exercise_set)} .dropdown-menu a[href='#{edit_workout_workout_exercise_exercise_set_path(workout, workout_exercise, exercise_set)}']")

    within("##{ActionView::RecordIdentifier.dom_id(workout_exercise)}") do
      expect(page).to have_css('form.edit-set-form')
      expect(page).to have_no_button('Add Set')
    end
  end

  it 'copies extended previous-session fields when using the Last button' do
    visit workout_path(workout)

    within("##{ActionView::RecordIdentifier.dom_id(workout_exercise)}") do
      click_button 'Add Set'
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

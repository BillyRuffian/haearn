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

  def expect_form_within_viewport(selector)
    measurements = page.evaluate_script(<<~JS, selector)
      (() => {
        const form = document.querySelector(arguments[0])
        if (!form) return null
        const rect = form.getBoundingClientRect()

        return {
          left: rect.left,
          right: rect.right,
          viewportWidth: window.innerWidth,
          scrollWidth: form.scrollWidth,
          clientWidth: form.clientWidth
        }
      })()
    JS

    expect(measurements).to be_present
    expect(measurements['left']).to be >= 0
    expect(measurements['right']).to be <= measurements['viewportWidth'] + 1
    expect(measurements['scrollWidth']).to be <= measurements['clientWidth'] + 1
  end

  def expect_form_to_fill_container(selector)
    widths = page.evaluate_script(<<~JS, selector)
      (() => {
        const form = document.querySelector(arguments[0])
        if (!form || !form.parentElement) return null

        return {
          form: form.getBoundingClientRect().width,
          container: form.parentElement.getBoundingClientRect().width
        }
      })()
    JS

    expect(widths).to be_present
    expect(widths['form']).to be_within(2).of(widths['container'])
  end

  it 'hides the add-set trigger when the add form is open and when editing a set' do
    visit workout_path(workout)

    within("##{ActionView::RecordIdentifier.dom_id(workout_exercise)}") do
      expect(page).to have_button('Add Set')
      click_button 'Add Set'
      expect(page).to have_css('form.add-set-form')
      expect(page).to have_no_button('Add Set')
      within('form.add-set-form') { click_button 'Cancel' }
      expect(page).to have_button('Add Set')
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

  it 'fits set forms to their available phone and desktop widths' do
    page.current_window.resize_to(390, 844)
    visit workout_path(workout)

    within("##{ActionView::RecordIdentifier.dom_id(workout_exercise)}") do
      click_button 'Add Set'
      find('summary', text: 'Equipment & Tracking').click
      page.execute_script("document.querySelector('form.add-set-form').scrollIntoView({ block: 'start' })")
    end

    expect_form_within_viewport('form.add-set-form')
    page.save_screenshot(Rails.root.join('tmp/set-form-add-mobile.png').to_s) if ENV['CAPTURE_SET_FORM'] == '1'

    visit workout_path(workout)
    open_inline_edit(
      edit_workout_workout_exercise_exercise_set_path(workout, workout_exercise, exercise_set),
      ActionView::RecordIdentifier.dom_id(exercise_set)
    )

    within("##{ActionView::RecordIdentifier.dom_id(workout_exercise)}") do
      expect(page).to have_css('form.edit-set-form')
      find('summary', text: 'Equipment & Tracking').click
      page.execute_script("document.querySelector('form.edit-set-form').scrollIntoView({ block: 'start' })")
    end

    expect_form_within_viewport('form.edit-set-form')
    page.save_screenshot(Rails.root.join('tmp/set-form-edit-mobile.png').to_s) if ENV['CAPTURE_SET_FORM'] == '1'

    page.current_window.resize_to(1280, 900)
    page.execute_script("document.querySelector('form.edit-set-form').scrollIntoView({ block: 'start' })")
    expect_form_within_viewport('form.edit-set-form')
    expect_form_to_fill_container('form.edit-set-form')
    page.save_screenshot(Rails.root.join('tmp/set-form-edit-desktop.png').to_s) if ENV['CAPTURE_SET_FORM'] == '1'
  end
end

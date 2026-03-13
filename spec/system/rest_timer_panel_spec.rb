require 'rails_helper'

RSpec.describe 'Rest timer panel', type: :system, js: true do
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

  it 'swaps between the start panel and countdown panel with the active sweep styling' do
    visit workout_path(workout)

    within('.rest-timer-footer') do
      expect(page).to have_button('Start Rest Timer')
      expect(page).to have_css("[data-rest-timer-target='collapsed']", visible: true)
      expect(page).to have_css("[data-rest-timer-target='container'].is-hidden", visible: :all)
      expect(page).to have_no_css("[data-rest-timer-target='display']", visible: true)

      click_button 'Start Rest Timer'

      expect(page).to have_no_button('Start Rest Timer')
      expect(page).to have_css("[data-rest-timer-target='collapsed'].is-hidden", visible: :all)
      expect(page).to have_css("[data-rest-timer-target='container']", visible: true)
      expect(page).to have_css("[data-rest-timer-target='display']", text: '1:30', visible: true)
    end

    progress_styles = page.evaluate_script(<<~JS)
      (() => {
        const progressBar = document.querySelector(".rest-timer-progress-bar")
        if (!progressBar) return null

        const style = window.getComputedStyle(progressBar)
        return {
          animationName: style.animationName,
          backgroundImage: style.backgroundImage
        }
      })()
    JS

    expect(progress_styles).not_to be_nil
    expect(progress_styles["animationName"]).to include("restTimerSweep")
    expect(progress_styles["backgroundImage"]).to include("linear-gradient")

    within('.rest-timer-footer') do
      find('.rest-timer-skip-btn').click

      expect(page).to have_button('Start Rest Timer')
      expect(page).to have_css("[data-rest-timer-target='collapsed']", visible: true)
      expect(page).to have_css("[data-rest-timer-target='container'].is-hidden", visible: :all)
      expect(page).to have_no_css("[data-rest-timer-target='display']", visible: true)
    end
  end

  it 'prefers the current user default over stale client-saved timer values' do
    user.update!(default_rest_seconds: 150)

    visit root_path
    page.execute_script(<<~JS)
      window.localStorage.setItem("haearn_rest_duration", "90")
      window.localStorage.setItem("haearn_rest_duration_default", "90")
    JS

    visit workout_path(workout)

    within('.rest-timer-footer') do
      click_button 'Start Rest Timer'
      expect(page).to have_css("[data-rest-timer-target='display']", text: '2:30', visible: true)
    end
  end

  it 'uses the user default for auto-started timers after logging a set' do
    visit workout_path(workout)

    page.execute_script(<<~JS)
      window.dispatchEvent(new CustomEvent("set-logged", { bubbles: true }))
    JS

    within('.rest-timer-footer') do
      expect(page).to have_css("[data-rest-timer-target='display']", text: '1:30', visible: true)
      find('.rest-timer-skip-btn').click
      expect(page).to have_button('Start Rest Timer')
      click_button 'Start Rest Timer'
      expect(page).to have_css("[data-rest-timer-target='display']", text: '1:30', visible: true)
    end
  end

  it 'shows an animated completion state before returning to the collapsed panel' do
    visit workout_path(workout)

    within('.rest-timer-footer') do
      click_button 'Start Rest Timer'
    end

    page.execute_script(<<~JS)
      const controllerElement = document.querySelector("[data-controller~='rest-timer']")
      const controller = window.Stimulus?.getControllerForElementAndIdentifier(controllerElement, "rest-timer")
      if (!controller) throw new Error("Missing rest-timer controller")
      controller.complete()
    JS

    within('.rest-timer-footer') do
      expect(page).to have_css(".rest-timer-bar.timer-complete", visible: true)
      expect(page).to have_css("[data-rest-timer-target='display']", text: '0:00', visible: true)
    end

    completion_styles = page.evaluate_script(<<~JS)
      (() => {
        const panel = document.querySelector(".rest-timer-bar.timer-complete")
        const progressBar = document.querySelector(".rest-timer-bar.timer-complete .rest-timer-progress-bar")
        const display = document.querySelector(".rest-timer-bar.timer-complete .rest-timer-display")
        if (!panel || !progressBar || !display) return null

        return {
          panelAnimation: window.getComputedStyle(panel).animationName,
          progressOpacity: window.getComputedStyle(progressBar.parentElement).opacity,
          progressAnimation: window.getComputedStyle(progressBar).animationName,
          displayAnimation: window.getComputedStyle(display).animationName
        }
      })()
    JS

    expect(completion_styles).not_to be_nil
    expect(completion_styles["panelAnimation"]).to include("timerPulseFill")
    expect(completion_styles["progressOpacity"].to_f).to be < 0.1
    expect(completion_styles["progressAnimation"]).to include("restTimerCompleteSweep")
    expect(completion_styles["displayAnimation"]).to include("restTimerCompleteFlash")
  end

  it 'hides the timer footer, add-exercise button, and mobile toolbar while add or edit set forms are active' do
    visit workout_path(workout)

    within("##{ActionView::RecordIdentifier.dom_id(workout_exercise)}") do
      click_button 'Add Set'
      expect(page).to have_css('form.add-set-form')
    end

    expect(page).to have_no_css('.rest-timer-footer', visible: true)
    expect(page).to have_no_css('.workout-fab', visible: true)
    expect(page).to have_no_css('.bottom-nav', visible: true)

    visit workout_path(workout)
    open_inline_edit(
      edit_workout_workout_exercise_exercise_set_path(workout, workout_exercise, exercise_set),
      ActionView::RecordIdentifier.dom_id(exercise_set)
    )

    expect(page).to have_css('form.edit-set-form')
    expect(page).to have_no_css('.rest-timer-footer', visible: true)
    expect(page).to have_no_css('.workout-fab', visible: true)
    expect(page).to have_no_css('.bottom-nav', visible: true)
  end

  it 'keeps only the running timer panel visible after navigating away and back' do
    visit workout_path(workout)

    within('.rest-timer-footer') do
      click_button 'Start Rest Timer'
      expect(page).to have_no_button('Start Rest Timer')
      expect(page).to have_css("[data-rest-timer-target='display']", visible: true)
    end

    visit root_path
    visit workout_path(workout)

    within('.rest-timer-footer') do
      expect(page).to have_no_button('Start Rest Timer')
      expect(page).to have_css("[data-rest-timer-target='display']", text: /\A1:\d{2}\z/, visible: true)
    end

    visible_panel_count = page.evaluate_script(<<~JS)
      (() => {
        return Array.from(document.querySelectorAll(".rest-timer-panel")).filter((panel) => {
          const style = window.getComputedStyle(panel)
          return !panel.hidden && style.display !== "none" && style.visibility !== "hidden" && style.opacity !== "0"
        }).length
      })()
    JS

    expect(visible_panel_count).to eq(1)
  end
end

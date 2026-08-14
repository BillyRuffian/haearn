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

  it 'swaps between the start panel and countdown panel with isolated active-fill styling' do
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
        const swooshStyle = window.getComputedStyle(progressBar, "::after")
        return {
          animationName: swooshStyle.animationName,
          backgroundImage: style.backgroundImage,
          overflow: style.overflow
        }
      })()
    JS

    expect(progress_styles).not_to be_nil
    expect(progress_styles["animationName"]).to include("restTimerSweep")
    expect(progress_styles["backgroundImage"]).to include("linear-gradient")
    expect(progress_styles["overflow"]).to eq('hidden')

    within('.rest-timer-footer') do
      find('.rest-timer-skip-btn').click

      expect(page).to have_button('Start Rest Timer')
      expect(page).to have_css("[data-rest-timer-target='collapsed']", visible: true)
      expect(page).to have_css("[data-rest-timer-target='container'].is-hidden", visible: :all)
      expect(page).to have_no_css("[data-rest-timer-target='display']", visible: true)
    end
  end

  it 'updates progress continuously without a blank frame or repeated digit writes' do
    visit workout_path(workout)

    motion = page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      const controllerElement = document.querySelector("[data-controller~='rest-timer']")
      const controller = window.Stimulus?.getControllerForElementAndIdentifier(controllerElement, "rest-timer")
      if (!controller) throw new Error("Missing rest-timer controller")

      controller.totalDuration = 10
      controller.start()
      controller.endTime = Date.now() + 5800

      const collapsed = document.querySelector("[data-rest-timer-target='collapsed']")
      const active = document.querySelector("[data-rest-timer-target='container']")
      const display = document.querySelector("[data-rest-timer-target='display']")
      const progress = document.querySelector("[data-rest-timer-target='progress']")
      const immediateState = {
        collapsedHidden: collapsed.hidden,
        activeHidden: active.hidden
      }

      setTimeout(() => {
        const first = { text: display.textContent, width: progress.style.width }
        setTimeout(() => {
          done({
            immediateState,
            first,
            second: { text: display.textContent, width: progress.style.width },
            usesAnimationFrame: controller.timerFrame !== null,
            hasLegacyInterval: Object.hasOwn(controller, "interval")
          })
        }, 180)
      }, 60)
    JS

    expect(motion.dig("immediateState", "collapsedHidden")).to be(true)
    expect(motion.dig("immediateState", "activeHidden")).to be(false)
    expect(motion.dig("first", "text")).to eq(motion.dig("second", "text"))
    expect(motion.dig("first", "width")).not_to eq(motion.dig("second", "width"))
    expect(motion["usesAnimationFrame"]).to be(true)
    expect(motion["hasLegacyInterval"]).to be(false)
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
          panelOverlayAnimation: window.getComputedStyle(panel, "::before").animationName,
          progressOpacity: window.getComputedStyle(progressBar.parentElement).opacity,
          progressAnimation: window.getComputedStyle(progressBar).animationName,
          displayAnimation: window.getComputedStyle(display).animationName
        }
      })()
    JS

    expect(completion_styles).not_to be_nil
    expect(completion_styles["panelOverlayAnimation"]).to include("restTimerCompleteSweep")
    expect(completion_styles["progressOpacity"].to_f).to be < 0.1
    expect(completion_styles["progressAnimation"]).to eq("none")
    expect(completion_styles["displayAnimation"]).to include("restTimerCompleteFlash")
    page.save_screenshot(Rails.root.join('tmp/rest-timer-desktop-complete.png')) if ENV['CAPTURE_TIMER'] == '1'
  end

  it 'cleanly replaces completion motion when a new rest period starts' do
    visit workout_path(workout)

    within('.rest-timer-footer') do
      click_button 'Start Rest Timer'
    end

    restart_state = page.evaluate_script(<<~JS)
      (() => {
        const controllerElement = document.querySelector("[data-controller~='rest-timer']")
        const controller = window.Stimulus?.getControllerForElementAndIdentifier(controllerElement, "rest-timer")
        controller.playAlert = () => {}
        controller.vibrate = () => {}
        controller.showNotification = () => {}
        controller.persistInAppNotification = () => Promise.resolve()
        controller.complete()
        window.dispatchEvent(new CustomEvent("set-logged", { bubbles: true }))

        return {
          className: controller.containerTarget.className,
          running: controller.isRunning,
          completionHoldTimeout: controller.completionHoldTimeout,
          completionFadeTimeout: controller.completionFadeTimeout,
          display: controller.displayTarget.textContent
        }
      })()
    JS

    expect(restart_state["running"]).to be(true)
    expect(restart_state["className"]).not_to include('timer-complete', 'timer-fade-out')
    expect(restart_state["completionHoldTimeout"]).to be_nil
    expect(restart_state["completionFadeTimeout"]).to be_nil
    expect(restart_state["display"]).to eq('1:30')
  end

  it 'plays countdown pips for the final four seconds before the completion tune' do
    visit workout_path(workout)

    within('.rest-timer-footer') do
      click_button 'Start Rest Timer'
    end

    page.execute_script(<<~JS)
      window.__restTimerCueLog = []
      window.__restTimerCueSeconds = []
      const controllerElement = document.querySelector("[data-controller~='rest-timer']")
      const controller = window.Stimulus?.getControllerForElementAndIdentifier(controllerElement, "rest-timer")
      if (!controller) throw new Error("Missing rest-timer controller")

      controller.playCountdownPip = () => window.__restTimerCueLog.push("pip")
      controller.renderCountdownCueVisual = (remaining) => window.__restTimerCueSeconds.push(remaining)
      controller.playAlert = () => window.__restTimerCueLog.push("alert")
      controller.vibrate = () => {}
      controller.showNotification = () => {}
      controller.persistInAppNotification = () => Promise.resolve()

      controller.endTime = Date.now() + 4100
      controller.saveTimerState()
    JS

    expect(page).to have_css("[data-rest-timer-target='display']", text: '0:00', visible: true, wait: 6)

    cue_log = page.evaluate_script("window.__restTimerCueLog")
    cue_seconds = page.evaluate_script("window.__restTimerCueSeconds")
    expect(cue_seconds).to eq([ 4, 3, 2, 1 ])
    expect(cue_log).to eq([ 'pip', 'pip', 'pip', 'pip', 'alert' ])
  end

  it 'pulses a visual cue with each final countdown pip before the completion gradient' do
    visit workout_path(workout)

    within('.rest-timer-footer') do
      click_button 'Start Rest Timer'
    end

    page.execute_script(<<~JS)
      const controllerElement = document.querySelector("[data-controller~='rest-timer']")
      const controller = window.Stimulus?.getControllerForElementAndIdentifier(controllerElement, "rest-timer")
      if (!controller) throw new Error("Missing rest-timer controller")

      controller.playCountdownPip = () => {}
      controller.endTime = Date.now() + 4000
      controller.saveTimerState()
      controller.resetCountdownCueState()
      controller.updateDisplay()
      controller.playCountdownCueIfNeeded(4)
    JS

    expect(page).to have_css('.rest-timer-bar.timer-cue-hot', visible: true)
    expect(page).to have_css('.rest-timer-bar.timer-cue-pulse', visible: true)

    cue_motion = page.evaluate_script(<<~JS)
      (() => {
        const panel = document.querySelector(".rest-timer-bar.timer-cue-pulse")
        const track = panel.querySelector(".rest-timer-progress")
        const progress = panel.querySelector(".rest-timer-progress-bar")
        const panelOverlay = window.getComputedStyle(panel, "::before")
        const swoosh = window.getComputedStyle(progress, "::after")
        const trackBounds = track.getBoundingClientRect()
        const progressBounds = progress.getBoundingClientRect()

        return {
          backgroundAnimationName: panelOverlay.animationName,
          panelOverlayOpacity: panelOverlay.opacity,
          swooshAnimationName: swoosh.animationName,
          trackAnimationName: window.getComputedStyle(track).animationName,
          trackBackgroundColor: window.getComputedStyle(track).backgroundColor,
          trackOverflow: window.getComputedStyle(track).overflow,
          trackWidth: trackBounds.width,
          progressWidth: progressBounds.width,
          progressRight: progressBounds.right,
          trackRight: trackBounds.right
        }
      })()
    JS
    expect(cue_motion["backgroundAnimationName"]).to include('restTimerCueBackgroundPulse')
    expect(cue_motion["panelOverlayOpacity"].to_f).to be > 0
    expect(cue_motion["swooshAnimationName"]).to include('restTimerSweep')
    expect(cue_motion["trackAnimationName"]).to eq('none')
    expect(cue_motion["trackBackgroundColor"]).to eq('rgb(48, 48, 52)')
    expect(cue_motion["trackOverflow"]).to eq('hidden')
    expect(cue_motion["progressWidth"].to_f / cue_motion["trackWidth"].to_f).to be_between(0.03, 0.06)
    expect(cue_motion["progressRight"].to_f).to be <= cue_motion["trackRight"].to_f
    page.save_screenshot(Rails.root.join('tmp/rest-timer-background-cue.png')) if ENV['CAPTURE_TIMER'] == '1'

    page.execute_script(<<~JS)
      const controllerElement = document.querySelector("[data-controller~='rest-timer']")
      const controller = window.Stimulus?.getControllerForElementAndIdentifier(controllerElement, "rest-timer")
      controller.playCountdownCueIfNeeded(3)
    JS

    expect(page).to have_css('.rest-timer-bar.timer-cue-hot', visible: true)

    page.execute_script(<<~JS)
      const controllerElement = document.querySelector("[data-controller~='rest-timer']")
      const controller = window.Stimulus?.getControllerForElementAndIdentifier(controllerElement, "rest-timer")
      controller.playCountdownCueIfNeeded(2)
    JS

    expect(page).to have_css('.rest-timer-bar.timer-cue-hot', visible: true)

    page.execute_script(<<~JS)
      const controllerElement = document.querySelector("[data-controller~='rest-timer']")
      const controller = window.Stimulus?.getControllerForElementAndIdentifier(controllerElement, "rest-timer")
      controller.playCountdownCueIfNeeded(1)
    JS

    expect(page).to have_css('.rest-timer-bar.timer-cue-hot', visible: true)
  end

  it 'warms and resumes the audio context across iPhone-style gesture and page return events' do
    visit workout_path(workout)

    page.execute_script(<<~JS)
      window.__restTimerAudioLifecycle = []
      const controllerElement = document.querySelector("[data-controller~='rest-timer']")
      const controller = window.Stimulus?.getControllerForElementAndIdentifier(controllerElement, "rest-timer")
      if (!controller) throw new Error("Missing rest-timer controller")

      controller.audioContext = {
        state: "suspended",
        resume() {
          window.__restTimerAudioLifecycle.push("resume")
          this.state = "running"
          return Promise.resolve()
        },
        sampleRate: 44100,
        currentTime: 0,
        destination: {},
        createBuffer() {
          return {}
        },
        createBufferSource() {
          return {
            buffer: null,
            connect() {},
            start() { window.__restTimerAudioLifecycle.push("warm") },
            stop() {}
          }
        },
        createGain() {
          return {
            gain: {
              value: 0,
              setValueAtTime() {},
              linearRampToValueAtTime() {},
              exponentialRampToValueAtTime() {}
            },
            connect() {}
          }
        }
      }
    JS

    page.execute_script("document.dispatchEvent(new Event('touchstart', { bubbles: true }))")
    page.execute_script("window.dispatchEvent(new Event('pageshow'))")

    lifecycle = page.evaluate_script("window.__restTimerAudioLifecycle")
    expect(lifecycle).to include('resume')
    expect(lifecycle).to include('warm')
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

  it 'keeps the timer footer geometry stable through phone-sized motion states' do
    page.current_window.resize_to(390, 844)
    visit workout_path(workout)

    collapsed_geometry = page.evaluate_script(<<~JS)
      (() => {
        const bounds = document.querySelector(".rest-timer-footer").getBoundingClientRect()
        return { top: bounds.top, bottom: bounds.bottom, height: bounds.height }
      })()
    JS

    within('.rest-timer-footer') do
      click_button 'Start Rest Timer'
    end

    active_geometry = page.evaluate_script(<<~JS)
      (() => {
        const bounds = document.querySelector(".rest-timer-footer").getBoundingClientRect()
        return { top: bounds.top, bottom: bounds.bottom, height: bounds.height }
      })()
    JS

    page.execute_script(<<~JS)
      const controllerElement = document.querySelector("[data-controller~='rest-timer']")
      const controller = window.Stimulus?.getControllerForElementAndIdentifier(controllerElement, "rest-timer")
      controller.playCountdownPip = () => {}
      controller.playCountdownCueIfNeeded(4)
    JS
    expect(page).to have_css('.rest-timer-bar.timer-cue-pulse', visible: true)
    page.save_screenshot(Rails.root.join('tmp/rest-timer-mobile-cue.png')) if ENV['CAPTURE_TIMER'] == '1'

    expect((collapsed_geometry["bottom"] - active_geometry["bottom"]).abs).to be < 1
    expect((collapsed_geometry["height"] - active_geometry["height"]).abs).to be < 2
  end

  it 'honors reduced motion while preserving timer progress' do
    page.driver.browser.execute_cdp('Emulation.setEmulatedMedia',
                                    features: [ { name: 'prefers-reduced-motion', value: 'reduce' } ])
    visit workout_path(workout)

    within('.rest-timer-footer') do
      click_button 'Start Rest Timer'
    end

    reduced_motion = page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      const controllerElement = document.querySelector("[data-controller~='rest-timer']")
      const controller = window.Stimulus?.getControllerForElementAndIdentifier(controllerElement, "rest-timer")
      const progress = document.querySelector("[data-rest-timer-target='progress']")
      const sheen = window.getComputedStyle(progress, "::after")
      const firstWidth = progress.style.width

      setTimeout(() => done({
        prefersReducedMotion: controller.prefersReducedMotion,
        frameType: controller.timerFrameType,
        sheenAnimation: sheen.animationName,
        firstWidth,
        secondWidth: progress.style.width
      }), 180)
    JS

    expect(reduced_motion["prefersReducedMotion"]).to be(true)
    expect(reduced_motion["frameType"]).to eq('timeout')
    expect(reduced_motion["sheenAnimation"]).to eq('none')
    expect(reduced_motion["firstWidth"]).to eq(reduced_motion["secondWidth"])
  ensure
    page.driver.browser.execute_cdp('Emulation.setEmulatedMedia', features: []) if page.driver.respond_to?(:browser)
  end

  it 'keeps only the running timer panel visible after navigating away and back' do
    visit workout_path(workout)

    within('.rest-timer-footer') do
      click_button 'Start Rest Timer'
      expect(page).to have_no_button('Start Rest Timer')
      expect(page).to have_css("[data-rest-timer-target='display']", visible: true)
    end

    visit root_path

    off_page_frame_type = page.evaluate_script(<<~JS)
      (() => {
        const controllerElement = document.querySelector("[data-controller~='rest-timer']")
        return window.Stimulus?.getControllerForElementAndIdentifier(controllerElement, "rest-timer")?.timerFrameType
      })()
    JS
    expect(off_page_frame_type).to eq('timeout')

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

    on_page_frame_type = page.evaluate_script(<<~JS)
      (() => {
        const controllerElement = document.querySelector("[data-controller~='rest-timer']")
        return window.Stimulus?.getControllerForElementAndIdentifier(controllerElement, "rest-timer")?.timerFrameType
      })()
    JS
    expect(on_page_frame_type).to eq('animation')
  end
end

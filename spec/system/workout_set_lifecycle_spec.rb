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

  def swipe_right(selector, distance: 96, end_event: 'touchend')
    page.execute_script(<<~JS, selector, distance, end_event)
      const element = document.querySelector(arguments[0])
      if (!element) throw new Error(`Missing swipe target: ${arguments[0]}`)

      const bounds = element.getBoundingClientRect()
      const y = bounds.top + (bounds.height / 2)
      const startX = bounds.left + Math.min(120, bounds.width / 3)
      const makeTouch = (x) => new Touch({
        identifier: 1,
        target: element,
        clientX: x,
        clientY: y,
        screenX: x,
        screenY: y,
        pageX: x + window.scrollX,
        pageY: y + window.scrollY
      })
      const start = makeTouch(startX)
      const moves = [24, Math.min(52, arguments[1]), arguments[1]].map((offset) => makeTouch(startX + offset))
      const finish = moves[moves.length - 1]

      element.dispatchEvent(new TouchEvent("touchstart", {
        bubbles: true,
        cancelable: true,
        touches: [start],
        targetTouches: [start],
        changedTouches: [start]
      }))
      moves.forEach((touch) => {
        element.dispatchEvent(new TouchEvent("touchmove", {
          bubbles: true,
          cancelable: true,
          touches: [touch],
          targetTouches: [touch],
          changedTouches: [touch]
        }))
      })
      element.dispatchEvent(new TouchEvent(arguments[2], {
        bubbles: true,
        cancelable: true,
        touches: [],
        targetTouches: [],
        changedTouches: [finish]
      }))
    JS
  end

  def make_block_scrollable(block_id)
    page.execute_script(<<~JS, block_id)
      const block = document.getElementById(arguments[0])
      if (!block) throw new Error(`Missing workout block: ${arguments[0]}`)

      const before = document.createElement("div")
      const after = document.createElement("div")
      before.style.height = "900px"
      after.style.height = "900px"
      block.before(before)
      block.after(after)
      window.scrollTo(0, 0)
    JS
  end

  def expect_action_clickable(selector)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    state = nil

    loop do
      state = page.evaluate_script(<<~JS, selector)
        (() => {
          const action = document.querySelector(arguments[0])
          const container = action.closest(".swipeable-container")
          const content = container.querySelector(".swipeable-content")
          const panel = action.closest(".swipe-actions")
          const bounds = action.getBoundingClientRect()
          const hit = document.elementFromPoint(bounds.left + (bounds.width / 2), bounds.top + (bounds.height / 2))
          return {
            clickable: action === hit || action.contains(hit),
            actionBounds: bounds.toJSON(),
            panelBounds: panel.getBoundingClientRect().toJSON(),
            contentTransform: content.style.transform,
            computedTransform: getComputedStyle(content).transform,
            hit: hit?.outerHTML?.slice(0, 300)
          }
        })()
      JS
      return if state['clickable']

      break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.05
    end

    raise "Swipe action never became clickable: #{selector} #{state.inspect}"
  end

  def expect_block_at_visible_top(block_id)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    geometry = nil

    loop do
      geometry = page.evaluate_script(<<~JS, block_id)
        (() => {
          const block = document.getElementById(arguments[0])
          const navbar = document.querySelector(".navbar.sticky-top")
          const navbarBounds = navbar?.getBoundingClientRect()
          const navbarBottom = navbarBounds?.top <= 0 && navbarBounds?.bottom > 0 ? navbarBounds.bottom : 0
          return {
            blockTop: block.getBoundingClientRect().top,
            navbarBottom,
            scrollY: window.scrollY,
            scrollHeight: document.documentElement.scrollHeight,
            innerHeight: window.innerHeight,
            bodyScrollHeight: document.body.scrollHeight,
            blockDocumentTop: window.scrollY + block.getBoundingClientRect().top
          }
        })()
      JS
      return if (geometry["blockTop"] - geometry["navbarBottom"]).abs < 8

      break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.05
    end

    raise "Workout block did not align to the visible viewport top: #{geometry.inspect}"
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

  it 'reveals duplicate on a partial right swipe and runs the revealed action' do
    page.current_window.resize_to(390, 844)
    visit workout_path(workout)

    swipe_selector = "##{ActionView::RecordIdentifier.dom_id(exercise_set)} .swipeable-container"
    page.execute_script("document.querySelector(arguments[0]).scrollIntoView({ block: 'center' })", swipe_selector)

    touch_action = page.evaluate_script("getComputedStyle(document.querySelector('#{swipe_selector}')).touchAction")
    expect(touch_action).to include('pan-y')
    expect(touch_action).to include('pinch-zoom')

    worker_update_cache = page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      navigator.serviceWorker.ready
        .then((registration) => done(registration.updateViaCache))
        .catch((error) => done(`error: ${error.message}`))
    JS
    expect(worker_update_cache).to eq('none')

    swipe_right(swipe_selector, distance: 52, end_event: 'touchcancel')
    within("##{ActionView::RecordIdentifier.dom_id(workout_exercise)}") do
      expect(page).to have_css(".set-row", count: 1)
    end

    swipe_right(swipe_selector)

    action_state = page.evaluate_script(<<~JS, swipe_selector)
      (() => {
        const container = document.querySelector(arguments[0])
        const action = container.querySelector("[data-swipeable-target='leftActions']")
        return { opacity: action.style.opacity, width: action.style.width }
      })()
    JS
    expect(action_state).to eq('opacity' => '1', 'width' => '80px')

    expect_action_clickable("#{swipe_selector} .swipe-action-duplicate")
    find("#{swipe_selector} .swipe-action-duplicate", visible: true).click

    within("##{ActionView::RecordIdentifier.dom_id(workout_exercise)}") do
      expect(page).to have_css(".set-row", count: 2)
    end
  end

  it 'duplicates with a full right swipe' do
    page.current_window.resize_to(390, 844)
    visit workout_path(workout)

    block_id = ActionView::RecordIdentifier.dom_id(workout_exercise.workout_block)
    make_block_scrollable(block_id)
    swipe_selector = "##{ActionView::RecordIdentifier.dom_id(exercise_set)} .swipeable-container"
    swipe_right(swipe_selector, distance: 260)

    within("##{ActionView::RecordIdentifier.dom_id(workout_exercise)}") do
      expect(page).to have_css(".set-row", count: 2)
    end
    expect_block_at_visible_top(block_id)
  end

  it 'duplicates when Safari cancels a full right swipe' do
    page.current_window.resize_to(390, 844)
    visit workout_path(workout)

    swipe_selector = "##{ActionView::RecordIdentifier.dom_id(exercise_set)} .swipeable-container"
    swipe_right(swipe_selector, distance: 260, end_event: 'touchcancel')

    within("##{ActionView::RecordIdentifier.dom_id(workout_exercise)}") do
      expect(page).to have_css(".set-row", count: 2)
    end
  end

  it 'duplicates by native form submission when requestSubmit is unavailable' do
    page.current_window.resize_to(390, 844)
    visit workout_path(workout)

    swipe_selector = "##{ActionView::RecordIdentifier.dom_id(exercise_set)} .swipeable-container"
    page.execute_script(<<~JS, swipe_selector)
      const form = document.querySelector(`${arguments[0]} .swipe-actions-left form`)
      if (!form) throw new Error("Missing swipe duplicate form")
      Object.defineProperty(form, "requestSubmit", { value: undefined })
    JS

    swipe_right(swipe_selector, distance: 260)

    within("##{ActionView::RecordIdentifier.dom_id(workout_exercise)}") do
      expect(page).to have_css(".set-row", count: 2)
    end
  end

  it 'scrolls its block to the visible top after logging a new set' do
    page.current_window.resize_to(390, 844)
    visit workout_path(workout)

    block_id = ActionView::RecordIdentifier.dom_id(workout_exercise.workout_block)
    make_block_scrollable(block_id)

    page.execute_script(<<~JS)
      const form = document.querySelector("form.add-set-form")
      if (!form) throw new Error("Missing add set form")
      form.requestSubmit()
    JS

    within("##{ActionView::RecordIdentifier.dom_id(workout_exercise)}") do
      expect(page).to have_css(".set-row", count: 2)
    end
    expect_block_at_visible_top(block_id)
  end
end

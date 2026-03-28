require 'rails_helper'

RSpec.describe 'Workout UI regressions', type: :request do
  let(:user) { users(:one) }
  let(:gym) { gyms(:one) }
  let(:exercise) { exercises(:one) }
  let(:machine) { machines(:one) }

  before do
    sign_in_as(user)
  end

  it 'shows add exercise FAB only for in-progress workouts' do
    active_workout = user.workouts.create!(gym: gym, started_at: Time.current, finished_at: nil)
    active_block = active_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    active_we = active_block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)
    active_we.exercise_sets.create!(position: 1, reps: 8, weight_kg: 40, is_warmup: false, completed_at: Time.current)

    get workout_path(active_workout)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('workout-fab')
    expect(response.body).to include(add_exercise_workout_path(active_workout))

    completed_workout = user.workouts.create!(
      gym: gym,
      started_at: 2.hours.ago,
      finished_at: 1.hour.ago
    )
    completed_block = completed_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    completed_we = completed_block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)
    completed_we.exercise_sets.create!(position: 1, reps: 8, weight_kg: 40, is_warmup: false, completed_at: 1.hour.ago)

    get workout_path(completed_workout)
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('workout-fab')
    expect(response.body).not_to include(add_exercise_workout_path(completed_workout))
  end

  it 'keeps the calendar link visible on the workout history page' do
    get workouts_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Calendar')
    expect(response.body).to include(calendar_workouts_path)
  end

  it 'renders the calendar page with initialized month navigation state' do
    get calendar_workouts_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Calendar')
    expect(response.body).to include(Date.current.strftime('%B %Y'))
    expect(response.body).to include(calendar_workouts_path(month: Date.current.beginning_of_month.prev_month.strftime('%Y-%m')))
  end

  it 'wires calendar day links back to history with from/to filters preserved in the form' do
    workout_date = Date.new(2026, 3, 12)
    user.workouts.create!(
      gym: gym,
      started_at: workout_date.noon,
      finished_at: workout_date.noon + 45.minutes
    )

    get calendar_workouts_path(month: workout_date.strftime('%Y-%m'))

    expect(response).to have_http_status(:ok)
    doc = Nokogiri::HTML.parse(response.body)
    day_links = doc.css(".calendar-day-link").map { |link| link["href"] }
    expect(day_links).to include(workouts_path(from: workout_date.to_s, to: workout_date.to_s))

    get workouts_path(from: workout_date.to_s, to: workout_date.to_s)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(name="from"))
    expect(response.body).to include(%(value="#{workout_date}"))
    expect(response.body).to include(%(name="to"))
    expect(response.body.scan(%(value="#{workout_date}")).length).to be >= 2
  end

  it 'renders exercise and equipment pickers in alphabetical order' do
    workout = user.workouts.create!(gym: gym, started_at: Time.current, finished_at: nil)
    swap_block = workout.workout_blocks.create!(position: 1, rest_seconds: 90)

    alpha_exercise = user.exercises.create!(name: 'Order Check Alpha', exercise_type: 'reps', has_weight: true, primary_muscle_group: 'chest')
    beta_exercise = user.exercises.create!(name: 'Order Check Beta', exercise_type: 'reps', has_weight: true, primary_muscle_group: 'chest')
    gamma_exercise = user.exercises.create!(name: 'Order Check Gamma', exercise_type: 'reps', has_weight: true, primary_muscle_group: 'chest')

    alpha_machine = gym.machines.create!(name: 'Order Rig Alpha', equipment_type: 'machine', display_unit: 'kg')
    beta_machine = gym.machines.create!(name: 'Order Rig Beta', equipment_type: 'machine', display_unit: 'kg')
    gamma_machine = gym.machines.create!(name: 'Order Rig Gamma', equipment_type: 'machine', display_unit: 'kg')

    workout_exercise = swap_block.workout_exercises.create!(exercise: gamma_exercise, machine: gamma_machine, position: 1)

    previous_workout = user.workouts.create!(gym: gym, started_at: 2.days.ago, finished_at: 2.days.ago + 45.minutes)
    previous_block = previous_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    previous_block.workout_exercises.create!(exercise: alpha_exercise, machine: beta_machine, position: 1)
    previous_block.workout_exercises.create!(exercise: alpha_exercise, machine: alpha_machine, position: 2)

    get add_exercise_workout_path(workout, search: 'Order Check')

    expect(response).to have_http_status(:ok)
    doc = Nokogiri::HTML.parse(response.body)
    exercise_names = doc.css("turbo-frame#exercise_list .list-group-item strong").map(&:text).select { |name| name.start_with?('Order Check') }
    expect(exercise_names).to eq([ 'Order Check Alpha', 'Order Check Beta', 'Order Check Gamma' ])

    get add_exercise_workout_path(workout, select_exercise: alpha_exercise.id)

    expect(response).to have_http_status(:ok)
    doc = Nokogiri::HTML.parse(response.body)
    machine_names = doc.css("[data-equipment-filter-target='item'] strong").map(&:text).select { |name| name.start_with?('Order Rig') }
    expect(machine_names).to eq([ 'Order Rig Alpha', 'Order Rig Beta', 'Order Rig Gamma' ])

    get swap_exercise_workout_workout_exercise_path(workout, workout_exercise, search: 'Order Check')

    expect(response).to have_http_status(:ok)
    doc = Nokogiri::HTML.parse(response.body)
    exercise_names = doc.css("turbo-frame#exercise_list .list-group-item strong").map(&:text).select { |name| name.start_with?('Order Check') }
    expect(exercise_names).to eq([ 'Order Check Alpha', 'Order Check Beta', 'Order Check Gamma' ])

    get swap_exercise_workout_workout_exercise_path(workout, workout_exercise, select_exercise: alpha_exercise.id)

    expect(response).to have_http_status(:ok)
    doc = Nokogiri::HTML.parse(response.body)
    machine_names = doc.css("[data-equipment-filter-target='item'] strong").map(&:text).select { |name| name.start_with?('Order Rig') }
    expect(machine_names).to eq([ 'Order Rig Alpha', 'Order Rig Beta', 'Order Rig Gamma' ])
  end

  it 'renders timer stage panels for smooth rest timer transitions' do
    workout = user.workouts.create!(gym: gym, started_at: Time.current, finished_at: nil)
    block = workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)

    get workout_path(workout)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('rest-timer-stage')
    expect(response.body).to include('rest-timer-collapsed rest-timer-panel')
    expect(response.body).to include('rest-timer-bar rest-timer-panel is-hidden')
    expect(response.body).to include('Start Rest Timer')
  end

  it 'mounts the rest timer with the user default duration in layout state' do
    user.update!(default_rest_seconds: 150)
    workout = user.workouts.create!(gym: gym, started_at: Time.current, finished_at: nil)
    block = workout.workout_blocks.create!(position: 1, rest_seconds: 150)
    block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)

    get workout_path(workout)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-controller="offline rest-timer"')
    expect(response.body).to include('data-rest-timer-duration-value="150"')
    expect(response.body).to include('data-rest-timer-default-duration-value="150"')
    expect(response.body).to include('>2:30<')
  end

  it 'uses machine display unit for set-level rows while user preference stays kg' do
    user.update!(preferred_unit: 'kg')
    machine = gym.machines.create!(
      name: 'Stack Machine LBS',
      equipment_type: 'machine',
      display_unit: 'lbs'
    )
    workout = user.workouts.create!(gym: gym, started_at: Time.current, finished_at: nil)
    block = workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    we = block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)
    we.exercise_sets.create!(position: 1, reps: 10, weight_kg: 45.36, is_warmup: false, completed_at: Time.current)

    get workout_path(workout)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('<small class="text-muted">lbs</small>')
    expect(response.body).to include('100')
  end

  it 'renders exercise and set modifier controls on active workout screen' do
    workout = user.workouts.create!(gym: gym, started_at: Time.current, finished_at: nil)
    block = workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    we = block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)
    set = we.exercise_sets.create!(position: 1, reps: 8, weight_kg: 40, is_warmup: false, completed_at: Time.current)

    get workout_path(workout)
    expect(response).to have_http_status(:ok)

    # Exercise-level modifier entry point.
    expect(response.body).to include('bi-sliders2-vertical')
    expect(response.body).to include('Exercise Variations')

    # Set-level menu should expose edit action.
    expect(response.body).to include(edit_workout_workout_exercise_exercise_set_path(workout, we, set))
    expect(response.body).to include("data-turbo-frame=\"exercise_set_#{set.id}\"")

    # Set-level disclosure toggles should be present in add-set form.
    expect(response.body).to include('Equipment & Tracking')
    expect(response.body).to include('Tempo')
  end

  it 'marks the inline set edit form so the add-set trigger can hide while editing' do
    workout = user.workouts.create!(gym: gym, started_at: Time.current, finished_at: nil)
    block = workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    we = block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)
    set = we.exercise_sets.create!(position: 1, reps: 8, weight_kg: 40, is_warmup: false, completed_at: Time.current)

    get edit_workout_workout_exercise_exercise_set_path(workout, we, set)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-add-set-toggle-target="editingForm"')
    expect(response.body).to include('edit-set-form')
  end

  it 'does not render block-specific rest controls in workout headers' do
    workout = user.workouts.create!(gym: gym, started_at: Time.current, finished_at: nil)
    block = workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)

    get workout_path(workout)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('data-controller="block-rest"')
    expect(response.body).not_to include('workout-block-rest')
  end

  it 'prefills add-set fields from prior context using ordered rules' do
    machine = gym.machines.create!(
      name: 'Rule Machine',
      equipment_type: 'machine',
      display_unit: 'kg',
      weight_ratio: 1
    )
    exercise = user.exercises.create!(
      name: 'Rule Exercise',
      exercise_type: 'reps',
      has_weight: true,
      primary_muscle_group: 'chest'
    )

    # Rule 1: no history -> blank defaults.
    no_history_workout = user.workouts.create!(gym: gym, started_at: Time.current, finished_at: nil)
    no_history_block = no_history_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    no_history_we = no_history_block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)

    get workout_path(no_history_workout)
    doc = Nokogiri::HTML.parse(response.body)
    frame = doc.at_css("turbo-frame#new_set_#{no_history_we.id}")
    expect(frame.at_css('input[name="exercise_set[weight_value]"]')['value'].to_s).to eq('')
    expect(frame.at_css('input[name="exercise_set[reps]"]')['value'].to_s).to eq('')
    expect(frame.at_css('input[type="checkbox"][name="exercise_set[is_warmup]"]')['checked']).to be_nil

    # Previous finished session for rule 2 source data.
    previous_workout = user.workouts.create!(gym: gym, started_at: 2.days.ago, finished_at: 2.days.ago + 50.minutes)
    previous_block = previous_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    previous_we = previous_block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)
    previous_we.exercise_sets.create!(
      position: 1,
      reps: 11,
      weight_kg: 42.5,
      is_warmup: true,
      completed_at: 2.days.ago + 10.minutes
    )
    previous_we.exercise_sets.create!(
      position: 2,
      reps: 7,
      weight_kg: 60,
      is_warmup: false,
      completed_at: 2.days.ago + 20.minutes
    )

    # Rule 2: first set copies first set from previous workout exercise+machine.
    first_set_workout = user.workouts.create!(gym: gym, started_at: Time.current, finished_at: nil)
    first_set_block = first_set_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    first_set_we = first_set_block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)

    get workout_path(first_set_workout)
    doc = Nokogiri::HTML.parse(response.body)
    frame = doc.at_css("turbo-frame#new_set_#{first_set_we.id}")
    expect(frame.at_css('input[name="exercise_set[weight_value]"]')['value']).to eq('42.5')
    expect(frame.at_css('input[name="exercise_set[reps]"]')['value']).to eq('11')
    expect(frame.at_css('input[type="checkbox"][name="exercise_set[is_warmup]"]')['checked']).to eq('checked')

    # Rule 3: second+ set copies the immediately previous set in current workout.
    first_set_we.exercise_sets.create!(
      position: 1,
      reps: 9,
      weight_kg: 55,
      is_warmup: false,
      rpe: 8.5,
      completed_at: Time.current
    )

    get workout_path(first_set_workout)
    doc = Nokogiri::HTML.parse(response.body)
    frame = doc.at_css("turbo-frame#new_set_#{first_set_we.id}")
    expect(frame.at_css('input[name="exercise_set[weight_value]"]')['value']).to eq('55')
    expect(frame.at_css('input[name="exercise_set[reps]"]')['value']).to eq('9')
    expect(frame.at_css('input[type="checkbox"][name="exercise_set[is_warmup]"]')['checked']).to be_nil
    expect(frame.at_css('input[name="exercise_set[rpe]"]')['value']).to eq('8.5')
  end

  it 'includes extended previous-session flags in the Last button payload' do
    machine = gym.machines.create!(
      name: 'Payload Machine',
      equipment_type: 'machine',
      display_unit: 'kg'
    )
    exercise = user.exercises.create!(
      name: 'Payload Exercise',
      exercise_type: 'reps',
      has_weight: true,
      primary_muscle_group: 'chest'
    )

    previous_workout = user.workouts.create!(gym: gym, started_at: 2.days.ago, finished_at: 2.days.ago + 45.minutes)
    previous_block = previous_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    previous_we = previous_block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)
    previous_we.exercise_sets.create!(
      position: 1,
      reps: 10,
      weight_kg: 40,
      is_warmup: true,
      is_amrap: false,
      set_type: 'normal',
      completed_at: 2.days.ago + 5.minutes
    )
    previous_we.exercise_sets.create!(
      position: 2,
      reps: 12,
      weight_kg: 47.5,
      is_warmup: false,
      is_amrap: true,
      set_type: 'backoff',
      belt: true,
      pain_flag: true,
      completed_at: 2.days.ago + 15.minutes
    )

    workout = user.workouts.create!(gym: gym, started_at: Time.current, finished_at: nil)
    block = workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    we = block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)
    we.exercise_sets.create!(
      position: 1,
      reps: 9,
      weight_kg: 42.5,
      is_warmup: true,
      completed_at: Time.current
    )

    get workout_path(workout)
    expect(response).to have_http_status(:ok)

    doc = Nokogiri::HTML.parse(response.body)
    payload_node = doc.at_css("[data-copy-last-payload-value]")
    expect(payload_node).to be_present

    payload = JSON.parse(payload_node["data-copy-last-payload-value"])
    expect(payload["weight_value"]).to eq("47.5")
    expect(payload["reps"]).to eq(12)
    expect(payload["is_warmup"]).to eq(false)
    expect(payload["is_amrap"]).to eq(true)
    expect(payload["set_type"]).to eq("backoff")
    expect(payload["belt"]).to eq(true)
    expect(payload["pain_flag"]).to eq(true)
  end

  it 'shows the most recent matching session in the Last summary instead of an older heavier session' do
    machine = gym.machines.create!(
      name: 'Last Summary Machine',
      equipment_type: 'machine',
      display_unit: 'kg'
    )
    exercise = user.exercises.create!(
      name: 'Last Summary Exercise',
      exercise_type: 'reps',
      has_weight: true,
      primary_muscle_group: 'chest'
    )

    older_workout = user.workouts.create!(gym: gym, started_at: 5.days.ago, finished_at: 5.days.ago + 45.minutes)
    older_block = older_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    older_we = older_block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)
    older_we.exercise_sets.create!(position: 1, reps: 5, weight_kg: 60, is_warmup: false, completed_at: 5.days.ago + 10.minutes)

    latest_workout = user.workouts.create!(gym: gym, started_at: 2.days.ago, finished_at: 2.days.ago + 45.minutes)
    latest_block = latest_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    latest_we = latest_block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)
    latest_we.exercise_sets.create!(position: 1, reps: 8, weight_kg: 45, is_warmup: false, completed_at: 2.days.ago + 10.minutes)
    latest_we.exercise_sets.create!(position: 2, reps: 8, weight_kg: 47.5, is_warmup: false, completed_at: 2.days.ago + 20.minutes)

    workout = user.workouts.create!(gym: gym, started_at: Time.current, finished_at: nil)
    block = workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)

    get workout_path(workout)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Last:')
    expect(response.body).to include('45kg × 8')
    expect(response.body).to include('47.5kg × 8')
    expect(response.body).not_to include('60kg × 5')
  end

  it 'scopes Last summary and payload to the exact machine' do
    target_machine = gym.machines.create!(
      name: 'Scoped Target Machine',
      equipment_type: 'machine',
      display_unit: 'kg'
    )
    other_machine = gym.machines.create!(
      name: 'Scoped Other Machine',
      equipment_type: 'machine',
      display_unit: 'kg'
    )
    exercise = user.exercises.create!(
      name: 'Scoped Last Exercise',
      exercise_type: 'reps',
      has_weight: true,
      primary_muscle_group: 'chest'
    )

    other_workout = user.workouts.create!(gym: gym, started_at: 2.days.ago, finished_at: 2.days.ago + 45.minutes)
    other_block = other_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    other_we = other_block.workout_exercises.create!(exercise: exercise, machine: other_machine, position: 1)
    other_we.exercise_sets.create!(position: 1, reps: 4, weight_kg: 80, is_warmup: false, completed_at: 2.days.ago + 10.minutes)

    target_workout = user.workouts.create!(gym: gym, started_at: 1.day.ago, finished_at: 1.day.ago + 45.minutes)
    target_block = target_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    target_we = target_block.workout_exercises.create!(exercise: exercise, machine: target_machine, position: 1)
    target_we.exercise_sets.create!(position: 1, reps: 10, weight_kg: 42.5, is_warmup: false, completed_at: 1.day.ago + 10.minutes)

    workout = user.workouts.create!(gym: gym, started_at: Time.current, finished_at: nil)
    block = workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    current_we = block.workout_exercises.create!(exercise: exercise, machine: target_machine, position: 1)

    get workout_path(workout)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('42.5kg × 10')
    expect(response.body).not_to include('80kg × 4')

    doc = Nokogiri::HTML.parse(response.body)
    payload_node = doc.at_css("#new_set_#{current_we.id} [data-copy-last-payload-value]")
    expect(payload_node).to be_present

    payload = JSON.parse(payload_node["data-copy-last-payload-value"])
    expect(payload["weight_value"]).to eq("42.5")
    expect(payload["reps"]).to eq(10)
  end

  it 'prefers earlier matching sets from the current workout over an older finished session' do
    machine = gym.machines.create!(
      name: 'Current Workout Last Machine',
      equipment_type: 'machine',
      display_unit: 'kg'
    )
    exercise = user.exercises.create!(
      name: 'Current Workout Last Exercise',
      exercise_type: 'reps',
      has_weight: true,
      primary_muscle_group: 'glutes'
    )

    previous_workout = user.workouts.create!(gym: gym, started_at: 4.days.ago, finished_at: 4.days.ago + 45.minutes)
    previous_block = previous_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    previous_we = previous_block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)
    previous_we.exercise_sets.create!(position: 1, reps: 15, weight_kg: 60, is_warmup: false, completed_at: 4.days.ago + 10.minutes)
    previous_we.exercise_sets.create!(position: 2, reps: 12, weight_kg: 60, is_warmup: false, completed_at: 4.days.ago + 20.minutes)

    workout = user.workouts.create!(gym: gym, started_at: Time.current, finished_at: nil)
    first_block = workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    first_we = first_block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)
    first_we.exercise_sets.create!(position: 1, reps: 15, weight_kg: 80, is_warmup: false, completed_at: Time.current - 20.minutes)
    first_we.exercise_sets.create!(position: 2, reps: 15, weight_kg: 80, is_warmup: false, completed_at: Time.current - 10.minutes)
    first_we.exercise_sets.create!(position: 3, reps: 15, weight_kg: 80, is_warmup: false, completed_at: Time.current - 5.minutes)

    current_block = workout.workout_blocks.create!(position: 2, rest_seconds: 90)
    current_we = current_block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)

    get workout_path(workout)

    expect(response).to have_http_status(:ok)
    doc = Nokogiri::HTML.parse(response.body)
    current_card = doc.at_css("##{ActionView::RecordIdentifier.dom_id(current_we)}")
    expect(current_card).to be_present
    expect(current_card.text).to include('80kg × 15')
    expect(current_card.text).not_to include('60kg × 12')

    payload_node = doc.at_css("#new_set_#{current_we.id} [data-copy-last-payload-value]")
    expect(payload_node).to be_present

    payload = JSON.parse(payload_node["data-copy-last-payload-value"])
    expect(payload["weight_value"]).to eq("80")
    expect(payload["reps"]).to eq(15)
  end

  it 'uses the nearest earlier matching exercise in the current workout instead of a later matching block' do
    machine = gym.machines.create!(
      name: 'Equivalent Set UI Machine',
      equipment_type: 'machine',
      display_unit: 'kg'
    )
    exercise = user.exercises.create!(
      name: 'Equivalent Set UI Exercise',
      exercise_type: 'reps',
      has_weight: true,
      primary_muscle_group: 'glutes'
    )

    workout = user.workouts.create!(gym: gym, started_at: Time.current, finished_at: nil)

    earlier_block = workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    earlier_we = earlier_block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)
    earlier_we.exercise_sets.create!(
      position: 1,
      reps: 15,
      weight_kg: 80,
      is_warmup: false,
      completed_at: Time.current - 20.minutes
    )

    current_block = workout.workout_blocks.create!(position: 2, rest_seconds: 90)
    current_we = current_block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)

    later_block = workout.workout_blocks.create!(position: 3, rest_seconds: 90)
    later_we = later_block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)
    later_we.exercise_sets.create!(
      position: 1,
      reps: 10,
      weight_kg: 60,
      is_warmup: false,
      completed_at: Time.current - 5.minutes
    )

    get workout_path(workout)

    expect(response).to have_http_status(:ok)
    doc = Nokogiri::HTML.parse(response.body)
    current_card = doc.at_css("##{ActionView::RecordIdentifier.dom_id(current_we)}")
    expect(current_card).to be_present
    expect(current_card.text).to include('80kg × 15')
    expect(current_card.text).not_to include('60kg × 10')

    payload_node = doc.at_css("#new_set_#{current_we.id} [data-copy-last-payload-value]")
    expect(payload_node).to be_present

    payload = JSON.parse(payload_node["data-copy-last-payload-value"])
    expect(payload["weight_value"]).to eq("80")
    expect(payload["reps"]).to eq(15)
  end

  it 'preserves visible workout-date chronology in the exercise history list' do
    machine = gym.machines.create!(
      name: 'History Chronology Machine',
      equipment_type: 'machine',
      display_unit: 'kg'
    )
    exercise = user.exercises.create!(
      name: 'History Chronology Exercise',
      exercise_type: 'reps',
      has_weight: true,
      primary_muscle_group: 'chest'
    )

    march_thirteenth_workout = user.workouts.create!(
      gym: gym,
      started_at: Time.zone.local(2026, 3, 13, 12, 0, 0),
      finished_at: nil
    )
    march_thirteenth_block = march_thirteenth_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    march_thirteenth_we = march_thirteenth_block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)
    march_thirteenth_first = march_thirteenth_we.exercise_sets.create!(
      position: 1,
      reps: 12,
      weight_kg: 40,
      is_warmup: false,
      completed_at: Time.zone.local(2026, 3, 13, 12, 15, 0)
    )
    march_thirteenth_second = march_thirteenth_we.exercise_sets.create!(
      position: 2,
      reps: 8,
      weight_kg: 47.5,
      is_warmup: false,
      completed_at: Time.zone.local(2026, 3, 13, 12, 25, 0)
    )
    march_thirteenth_first.update_columns(created_at: Time.current)
    march_thirteenth_second.update_columns(created_at: 4.days.ago)

    march_sixth_workout = user.workouts.create!(
      gym: gym,
      started_at: Time.zone.local(2026, 3, 6, 12, 0, 0),
      finished_at: nil
    )
    march_sixth_block = march_sixth_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    march_sixth_we = march_sixth_block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)
    march_sixth_we.exercise_sets.create!(
      position: 1,
      reps: 6,
      weight_kg: 60,
      is_warmup: false,
      completed_at: Time.zone.local(2026, 3, 6, 12, 20, 0)
    )

    february_eleventh_workout = user.workouts.create!(
      gym: gym,
      started_at: Time.zone.local(2026, 2, 11, 12, 0, 0),
      finished_at: Time.zone.local(2026, 2, 11, 13, 0, 0)
    )
    february_eleventh_block = february_eleventh_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    february_eleventh_we = february_eleventh_block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)
    february_eleventh_we.exercise_sets.create!(
      position: 1,
      reps: 15,
      weight_kg: 60,
      is_warmup: false,
      completed_at: Time.zone.local(2026, 2, 11, 12, 15, 0)
    )

    february_third_workout = user.workouts.create!(
      gym: gym,
      started_at: Time.zone.local(2026, 2, 3, 12, 0, 0),
      finished_at: Time.zone.local(2026, 2, 3, 13, 0, 0)
    )
    february_third_block = february_third_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    february_third_we = february_third_block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)
    february_third_we.exercise_sets.create!(
      position: 1,
      reps: 15,
      weight_kg: 50,
      is_warmup: false,
      completed_at: Time.zone.local(2026, 2, 3, 12, 15, 0)
    )

    get history_exercise_path(exercise, machine_id: machine.id)

    expect(response).to have_http_status(:ok)

    doc = Nokogiri::HTML.parse(response.body)
    history_root = doc.at_css("#machine-#{machine.id}.tab-pane.show.active") || doc
    visible_dates = history_root.css('.history-session h6').map do |heading|
      heading.text.gsub(/\s+PR\b/, '').squish
    end

    expect(visible_dates.first(4)).to eq(
      [
        'Friday, March 13, 2026',
        'Friday, March 6, 2026',
        'Wednesday, February 11, 2026',
        'Tuesday, February 3, 2026'
      ]
    )
  end

  it 'does not render redundant All and machine tabs when only one machine history bucket exists' do
    machine = gym.machines.create!(
      name: 'Single Bucket Machine',
      equipment_type: 'machine',
      display_unit: 'kg'
    )
    exercise = user.exercises.create!(
      name: 'Single Bucket Exercise',
      exercise_type: 'reps',
      has_weight: true,
      primary_muscle_group: 'glutes'
    )

    workout = user.workouts.create!(
      gym: gym,
      started_at: Time.zone.local(2026, 3, 13, 12, 0, 0),
      finished_at: Time.zone.local(2026, 3, 13, 13, 0, 0)
    )
    block = workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    workout_exercise = block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)
    workout_exercise.exercise_sets.create!(
      position: 1,
      reps: 12,
      weight_kg: 80,
      is_warmup: false,
      completed_at: Time.zone.local(2026, 3, 13, 12, 15, 0)
    )

    get history_exercise_path(exercise, machine_id: machine.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('data-bs-target="#all-machines"')
    expect(response.body).not_to include("data-bs-target=\"#machine-#{machine.id}\"")
    expect(response.body.scan('Friday, March 13, 2026').length).to eq(1)
  end

  it 'uses machine_id as the active history tab without hiding other machine tabs' do
    current_machine = gym.machines.create!(
      name: 'Current History Machine',
      equipment_type: 'machine',
      display_unit: 'kg'
    )
    other_machine = gym.machines.create!(
      name: 'Other History Machine',
      equipment_type: 'machine',
      display_unit: 'kg'
    )
    exercise = user.exercises.create!(
      name: 'Tabbed History Exercise',
      exercise_type: 'reps',
      has_weight: true,
      primary_muscle_group: 'chest'
    )

    current_workout = user.workouts.create!(gym: gym, started_at: 2.days.ago, finished_at: 2.days.ago + 45.minutes)
    current_block = current_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    current_block.workout_exercises.create!(exercise: exercise, machine: current_machine, position: 1).exercise_sets.create!(
      position: 1,
      reps: 8,
      weight_kg: 50,
      is_warmup: false,
      completed_at: 2.days.ago + 10.minutes
    )

    other_workout = user.workouts.create!(gym: gym, started_at: 1.day.ago, finished_at: 1.day.ago + 45.minutes)
    other_block = other_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    other_block.workout_exercises.create!(exercise: exercise, machine: other_machine, position: 1).exercise_sets.create!(
      position: 1,
      reps: 10,
      weight_kg: 42.5,
      is_warmup: false,
      completed_at: 1.day.ago + 10.minutes
    )

    get history_exercise_path(exercise, machine_id: current_machine.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Current History Machine (1)")
    expect(response.body).to include("Other History Machine (1)")
    expect(response.body).to include(%(nav-link active" data-bs-toggle="tab" data-bs-target="#machine-#{current_machine.id}"))
    expect(response.body).to include(%(tab-pane fade show active" id="machine-#{current_machine.id}"))
    expect(response.body).to include('42.5kg × 10')
    expect(response.body).to include('50kg × 8')
  end

  it 'shows progression updates only after workout completion' do
    allow_any_instance_of(ProgressionSuggester).to receive(:suggest).and_return(
      {
        current_weight_kg: 40.0,
        suggested_weight_kg: 45.0,
        increase_kg: 5.0,
        reasons: [ 'consistently hitting 10 reps' ]
      }
    )

    active_workout = user.workouts.create!(gym: gym, started_at: Time.current, finished_at: nil)
    active_block = active_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    active_block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)

    get workout_path(active_workout)
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('Progression Updates')

    completed_workout = user.workouts.create!(gym: gym, started_at: 2.hours.ago, finished_at: 1.hour.ago)
    completed_block = completed_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    completed_block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)

    get workout_path(completed_workout)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Progression Updates')
    expect(response.body).to include('Ready to progress.')
  end
end

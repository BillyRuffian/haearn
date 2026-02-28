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

  it 'renders timer stage panels for smooth rest timer transitions' do
    workout = user.workouts.create!(gym: gym, started_at: Time.current, finished_at: nil)
    block = workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)

    get workout_path(workout)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('rest-timer-stage')
    expect(response.body).to include('rest-timer-collapsed rest-timer-panel')
    expect(response.body).to include('rest-timer-bar rest-timer-panel is-hidden')
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

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
end

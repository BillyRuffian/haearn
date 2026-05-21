require 'rails_helper'

RSpec.describe 'Core functionality', type: :request do
  let(:user) { users(:one) }
  let(:gym) { gyms(:one) }

  it 'redirects unauthenticated users to sign in' do
    get workouts_path
    expect(response).to redirect_to(new_session_path)
  end

  it 'supports workout lifecycle: start, add exercise, log set, finish' do
    sign_in_as(user)

    exercise = user.exercises.create!(
      name: 'Incline Press',
      exercise_type: 'reps',
      has_weight: true,
      primary_muscle_group: 'chest'
    )
    machine = gym.machines.create!(
      name: 'Incline Stack',
      equipment_type: 'machine',
      display_unit: 'lbs'
    )

    expect do
      post workouts_path, params: { workout: { gym_id: gym.id } }
    end.to change(user.workouts, :count).by(1)
    workout = user.workouts.order(:id).last
    expect(response).to redirect_to(workout_path(workout))

    expect do
      post add_exercise_workout_path(workout), params: { exercise_id: exercise.id, machine_id: machine.id }
    end.to change(workout.workout_exercises, :count).by(1)
    expect(response).to redirect_to(workout_path(workout))
    workout_exercise = workout.workout_exercises.order(:id).last

    expect do
      post workout_workout_exercise_exercise_sets_path(workout, workout_exercise), params: {
        exercise_set: {
          weight_value: '100',
          reps: '8',
          is_warmup: '0'
        }
      }
    end.to change(workout_exercise.exercise_sets, :count).by(1)
    expect(response).to redirect_to(workout_path(workout))

    logged_set = workout_exercise.exercise_sets.order(:id).last
    expect(logged_set.weight_kg.to_f).to be_within(0.05).of(45.36)
    expect(logged_set.reps).to eq(8)

    patch finish_workout_path(workout)
    expect(response).to redirect_to(workout_path(workout))
    expect(workout.reload.finished_at).to be_present

    get workout_path(workout)
    expect(response.body).not_to include('workout-fab')
  end

  it 'round-trips whole-pound exercise weights without rendering float drift' do
    sign_in_as(user)
    user.update!(preferred_unit: 'lbs')

    exercise = user.exercises.create!(
      name: 'Round Trip Press',
      exercise_type: 'reps',
      has_weight: true,
      primary_muscle_group: 'chest'
    )
    machine = gym.machines.create!(
      name: 'Round Trip Rack',
      equipment_type: 'machine',
      display_unit: nil
    )

    workout = user.workouts.create!(gym: gym, started_at: Time.current, finished_at: nil)
    block = workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    workout_exercise = block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)

    post workout_workout_exercise_exercise_sets_path(workout, workout_exercise), params: {
      exercise_set: {
        weight_value: '165',
        reps: '5',
        is_warmup: '0'
      }
    }

    expect(response).to redirect_to(workout_path(workout))

    logged_set = workout_exercise.exercise_sets.order(:id).last
    expect(logged_set.weight_kg.to_f).to be_within(0.000001).of(74.842741)

    get workout_path(workout)
    expect(response.body).to include('165')
    expect(response.body).not_to include('164.99')

    get edit_workout_workout_exercise_exercise_set_path(workout, workout_exercise, logged_set)
    expect(response.body).to include('value="165"')
    expect(response.body).not_to include('164.99')
  end

  it 'updates key settings preferences' do
    sign_in_as(user)

    patch settings_path, params: {
      user: {
        preferred_unit: 'lbs',
        default_rest_seconds: 120,
        progression_rep_target: 12
      }
    }

    expect(response).to redirect_to(settings_path)
    user.reload
    expect(user.preferred_unit).to eq('lbs')
    expect(user.default_rest_seconds).to eq(120)
    expect(user.progression_rep_target).to eq(12)
  end

  it 'uses the user default rest when workout logging creates a new block' do
    sign_in_as(user)
    user.update!(default_rest_seconds: 150)

    workout = user.workouts.create!(gym: gym, started_at: Time.current, finished_at: nil)
    first_exercise = user.exercises.create!(
      name: 'Flat Press',
      exercise_type: 'reps',
      has_weight: true,
      primary_muscle_group: 'chest'
    )
    second_exercise = user.exercises.create!(
      name: 'Chest Fly',
      exercise_type: 'reps',
      has_weight: true,
      primary_muscle_group: 'chest'
    )
    machine = gym.machines.create!(
      name: 'Default Rest Stack',
      equipment_type: 'machine',
      display_unit: 'kg'
    )

    post add_exercise_workout_path(workout), params: {
      exercise_id: first_exercise.id,
      machine_id: machine.id
    }

    expect(response).to redirect_to(workout_path(workout))
    created_block = workout.reload.workout_blocks.sole
    expect(created_block.rest_seconds).to eq(150)

    movable_exercise = created_block.workout_exercises.create!(
      exercise: second_exercise,
      machine: machine,
      position: 2
    )

    patch move_to_block_workout_workout_exercise_path(workout, movable_exercise), params: {
      target_block_id: 'new'
    }

    expect(response).to redirect_to(workout_path(workout))
    expect(movable_exercise.reload.workout_block.rest_seconds).to eq(150)
  end

  it 'adds a superset exercise into the existing block instead of creating a new block' do
    sign_in_as(user)

    workout = user.workouts.create!(gym: gym, started_at: Time.current, finished_at: nil)
    first_exercise = user.exercises.create!(
      name: 'Superset Press',
      exercise_type: 'reps',
      has_weight: true,
      primary_muscle_group: 'chest'
    )
    second_exercise = user.exercises.create!(
      name: 'Superset Row',
      exercise_type: 'reps',
      has_weight: true,
      primary_muscle_group: 'back'
    )
    machine = gym.machines.create!(
      name: 'Superset Stack',
      equipment_type: 'machine',
      display_unit: 'kg'
    )

    post add_exercise_workout_path(workout), params: {
      exercise_id: first_exercise.id,
      machine_id: machine.id
    }

    expect(response).to redirect_to(workout_path(workout))
    original_block = workout.reload.workout_blocks.sole

    get add_exercise_workout_path(workout, to_block: original_block.id)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Add to Superset')
    expect(response.body).to include("to_block=#{original_block.id}")

    expect do
      post add_exercise_workout_path(workout, to_block: original_block.id), params: {
        exercise_id: second_exercise.id,
        machine_id: machine.id
      }
    end.not_to change(workout.reload.workout_blocks, :count)

    expect(response).to redirect_to(workout_path(workout))
    expect(original_block.reload.workout_exercises.order(:position).pluck(:exercise_id)).to eq([ first_exercise.id, second_exercise.id ])

    get workout_path(workout)

    expect(response).to have_http_status(:ok)
    expect(response.body.scan(/id="#{ActionView::RecordIdentifier.dom_id(original_block)}"/).length).to eq(1)
    expect(response.body).to include('Superset A')
    expect(response.body).to include('Alternate A1 and A2, then rest.')
    expect(response.body).to include('workout-block--superset')
    expect(response.body).to include('workout-block-superset-link')
    expect(response.body).to include('A1')
    expect(response.body).to include('A2')
  end

  it 'excludes retired equipment from future workout machine selection while preserving history on the gym page' do
    sign_in_as(user)

    active_machine = gym.machines.create!(
      name: 'Active Selector Machine',
      equipment_type: 'machine',
      display_unit: 'kg'
    )
    retired_machine = gym.machines.create!(
      name: 'Retired Selector Machine',
      equipment_type: 'machine',
      display_unit: 'kg',
      retired_at: Time.current
    )
    exercise = user.exercises.create!(
      name: 'Retired Machine Test Exercise',
      exercise_type: 'reps',
      has_weight: true,
      primary_muscle_group: 'chest'
    )

    workout = user.workouts.create!(gym: gym, started_at: Time.current, finished_at: nil)

    get add_exercise_workout_path(workout, select_exercise: exercise.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Active Selector Machine')
    expect(response.body).not_to include('Retired Selector Machine')

    get gym_path(gym)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Retired Equipment')
    expect(response.body).to include('Retired Selector Machine')
    expect(response.body).to include('Retired')
    expect(response.body).to include('Active Selector Machine')
    expect(active_machine.reload.active?).to eq(true)
    expect(retired_machine.reload.retired?).to eq(true)
  end
end

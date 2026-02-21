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
end

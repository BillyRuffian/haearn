require 'rails_helper'

RSpec.describe WorkoutExerciseVolumeComparison do
  let(:user) { users(:one) }
  let(:gym) { gyms(:one) }
  let(:exercise) do
    user.exercises.create!(
      name: 'Volume Comparison Press',
      exercise_type: 'reps',
      has_weight: true,
      primary_muscle_group: 'chest'
    )
  end
  let(:machine) { gym.machines.create!(name: 'Volume Press', equipment_type: 'machine') }

  it 'compares working-set volume with completed history for the exact exercise and machine' do
    historical_workout_exercise = create_workout_exercise(machine: machine, finished: true)
    historical_workout_exercise.exercise_sets.create!(weight_kg: 100, reps: 10, is_warmup: false, position: 1)
    historical_workout_exercise.exercise_sets.create!(weight_kg: 60, reps: 10, is_warmup: true, position: 2)

    other_machine = gym.machines.create!(name: 'Other Volume Press', equipment_type: 'machine')
    other_machine_history = create_workout_exercise(machine: other_machine, finished: true)
    other_machine_history.exercise_sets.create!(weight_kg: 300, reps: 10, is_warmup: false, position: 1)

    equipment_free_history = create_workout_exercise(machine: nil, finished: true)
    equipment_free_history.exercise_sets.create!(weight_kg: 250, reps: 10, is_warmup: false, position: 1)

    current = create_workout_exercise(machine: machine, finished: false)
    current.exercise_sets.create!(weight_kg: 80, reps: 10, is_warmup: false, position: 1)
    current.exercise_sets.create!(weight_kg: 40, reps: 10, is_warmup: true, position: 2)

    comparison = described_class.for(current)

    expect(comparison).to include(
      current_volume_kg: 800,
      previous_max_volume_kg: 1000,
      max_volume_kg: 1000,
      volume_pr: false
    )

    equipment_free_current = create_workout_exercise(machine: nil, finished: false)
    equipment_free_current.exercise_sets.create!(weight_kg: 100, reps: 10, is_warmup: false, position: 1)

    expect(described_class.for(equipment_free_current)).to include(
      current_volume_kg: 1000,
      previous_max_volume_kg: 2500,
      max_volume_kg: 2500,
      volume_pr: false
    )
  end

  it 'raises the all-time maximum and PR state when the current session exceeds history' do
    historical = create_workout_exercise(machine: machine, finished: true)
    historical.exercise_sets.create!(weight_kg: 50, reps: 10, is_warmup: false, position: 1)

    current = create_workout_exercise(machine: machine, finished: false)
    current.exercise_sets.create!(weight_kg: 60, reps: 10, is_warmup: false, position: 1)

    expect(described_class.for(current)).to include(
      current_volume_kg: 600,
      previous_max_volume_kg: 500,
      max_volume_kg: 600,
      volume_pr: true
    )
  end

  private

  def create_workout_exercise(machine:, finished:)
    workout = user.workouts.create!(
      gym: gym,
      started_at: Time.current,
      finished_at: finished ? Time.current : nil
    )
    block = workout.workout_blocks.create!(position: 1)
    block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)
  end
end

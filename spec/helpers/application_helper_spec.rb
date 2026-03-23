require 'rails_helper'
require 'ostruct'

RSpec.describe ApplicationHelper, type: :helper do
  before do
    Current.session = users(:one).sessions.create!
  end

  after do
    Current.reset
  end

  describe '#set_weight_display_for / #set_weight_unit_for' do
    it 'uses machine display unit when machine unit exists' do
      machine = Machine.new(display_unit: 'lbs')
      workout_exercise = OpenStruct.new(machine: machine)

      expect(helper.set_weight_display_for(45.36, workout_exercise)).to eq('100')
      expect(helper.set_weight_unit_for(workout_exercise)).to eq('lbs')
    end

    it 'falls back to user preferred unit when machine unit is absent' do
      workout_exercise = OpenStruct.new(machine: nil)

      expect(helper.set_weight_display_for(45.36, workout_exercise)).to eq('45.36')
      expect(helper.set_weight_unit_for(workout_exercise)).to eq('kg')
    end
  end

  describe '#previous_session_set_data' do
    it 'returns converted weight plus extended flags from the matching previous set' do
      user = users(:one)
      gym = gyms(:one)
      machine = gym.machines.create!(name: 'Helper Machine', equipment_type: 'machine', display_unit: 'lbs')
      exercise = user.exercises.create!(
        name: 'Helper Exercise',
        exercise_type: 'reps',
        has_weight: true,
        primary_muscle_group: 'chest'
      )

      previous_workout = user.workouts.create!(gym: gym, started_at: 2.days.ago, finished_at: 2.days.ago + 30.minutes)
      previous_block = previous_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
      previous_we = previous_block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)
      previous_we.exercise_sets.create!(
        position: 1,
        weight_kg: 45.36,
        reps: 8,
        is_warmup: true,
        is_amrap: false,
        set_type: 'normal',
        completed_at: 2.days.ago + 5.minutes
      )
      previous_we.exercise_sets.create!(
        position: 2,
        weight_kg: 47.63,
        reps: 6,
        is_warmup: false,
        is_amrap: true,
        set_type: 'backoff',
        completed_at: 2.days.ago + 10.minutes
      )

      current_workout = user.workouts.create!(gym: gym, started_at: Time.current, finished_at: nil)
      current_block = current_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
      current_we = current_block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)

      data = helper.previous_session_set_data(current_we, 2)

      expect(data["weight_value"]).to eq("105.01")
      expect(data["reps"]).to eq(6)
      expect(data["is_warmup"]).to eq(false)
      expect(data["is_amrap"]).to eq(true)
      expect(data["set_type"]).to eq("backoff")
    end

    it 'uses session completion order rather than set created_at order' do
      user = users(:one)
      gym = gyms(:one)
      machine = gym.machines.create!(name: 'Order Helper Machine', equipment_type: 'machine', display_unit: 'kg')
      exercise = user.exercises.create!(
        name: 'Order Helper Exercise',
        exercise_type: 'reps',
        has_weight: true,
        primary_muscle_group: 'chest'
      )

      previous_workout = user.workouts.create!(gym: gym, started_at: 2.days.ago, finished_at: 2.days.ago + 30.minutes)
      previous_block = previous_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
      previous_we = previous_block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)

      first_set = previous_we.exercise_sets.create!(
        position: 1,
        weight_kg: 40,
        reps: 12,
        completed_at: 2.days.ago + 5.minutes
      )
      second_set = previous_we.exercise_sets.create!(
        position: 2,
        weight_kg: 47.5,
        reps: 8,
        completed_at: 2.days.ago + 15.minutes
      )

      first_set.update_columns(created_at: Time.current)
      second_set.update_columns(created_at: 3.days.ago)

      current_workout = user.workouts.create!(gym: gym, started_at: Time.current, finished_at: nil)
      current_block = current_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
      current_we = current_block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)

      first_payload = helper.previous_session_set_data(current_we, 1)
      second_payload = helper.previous_session_set_data(current_we, 2)

      expect(first_payload["weight_value"]).to eq("40")
      expect(first_payload["reps"]).to eq(12)
      expect(second_payload["weight_value"]).to eq("47.5")
      expect(second_payload["reps"]).to eq(8)
    end

    it 'uses the most recently finished matching session rather than the most recently started one' do
      user = users(:one)
      gym = gyms(:one)
      machine = gym.machines.create!(name: 'Chronology Helper Machine', equipment_type: 'machine', display_unit: 'kg')
      exercise = user.exercises.create!(
        name: 'Chronology Helper Exercise',
        exercise_type: 'reps',
        has_weight: true,
        primary_muscle_group: 'chest'
      )

      longer_session = user.workouts.create!(
        gym: gym,
        started_at: 3.days.ago,
        finished_at: 1.day.ago
      )
      longer_block = longer_session.workout_blocks.create!(position: 1, rest_seconds: 90)
      longer_we = longer_block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)
      longer_we.exercise_sets.create!(
        position: 1,
        weight_kg: 52.5,
        reps: 7,
        completed_at: 1.day.ago - 10.minutes
      )

      later_started_session = user.workouts.create!(
        gym: gym,
        started_at: 2.days.ago,
        finished_at: 2.days.ago + 45.minutes
      )
      later_started_block = later_started_session.workout_blocks.create!(position: 1, rest_seconds: 90)
      later_started_we = later_started_block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)
      later_started_we.exercise_sets.create!(
        position: 1,
        weight_kg: 47.5,
        reps: 10,
        completed_at: 2.days.ago + 20.minutes
      )

      current_workout = user.workouts.create!(gym: gym, started_at: Time.current, finished_at: nil)
      current_block = current_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
      current_we = current_block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)

      payload = helper.previous_session_set_data(current_we, 1)

      expect(payload["weight_value"]).to eq("52.5")
      expect(payload["reps"]).to eq(7)
    end

    it 'ignores prior sessions for the same exercise on different equipment' do
      user = users(:one)
      gym = gyms(:one)
      target_machine = gym.machines.create!(name: 'Scope Target Machine', equipment_type: 'machine', display_unit: 'kg')
      other_machine = gym.machines.create!(name: 'Scope Other Machine', equipment_type: 'machine', display_unit: 'kg')
      exercise = user.exercises.create!(
        name: 'Scope Helper Exercise',
        exercise_type: 'reps',
        has_weight: true,
        primary_muscle_group: 'chest'
      )

      previous_workout = user.workouts.create!(gym: gym, started_at: 2.days.ago, finished_at: 2.days.ago + 30.minutes)
      previous_block = previous_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
      previous_block.workout_exercises.create!(exercise: exercise, machine: other_machine, position: 1).exercise_sets.create!(
        position: 1,
        weight_kg: 80,
        reps: 4,
        completed_at: 2.days.ago + 5.minutes
      )

      current_workout = user.workouts.create!(gym: gym, started_at: Time.current, finished_at: nil)
      current_block = current_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
      current_we = current_block.workout_exercises.create!(exercise: exercise, machine: target_machine, position: 1)

      expect(helper.previous_session_set_data(current_we, 1)).to be_nil
      expect(helper.last_weight_for(current_we)).to be_nil
      expect(helper.last_reps_for(current_we)).to be_nil
    end
  end

  describe '#last_weight_for / #last_reps_for' do
    it 'uses the most recently completed set from the previous matching session' do
      user = users(:one)
      gym = gyms(:one)
      machine = gym.machines.create!(name: 'Last Helper Machine', equipment_type: 'machine', display_unit: 'kg')
      exercise = user.exercises.create!(
        name: 'Last Helper Exercise',
        exercise_type: 'reps',
        has_weight: true,
        primary_muscle_group: 'chest'
      )

      previous_workout = user.workouts.create!(gym: gym, started_at: 2.days.ago, finished_at: 2.days.ago + 30.minutes)
      previous_block = previous_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
      previous_we = previous_block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)

      earlier_completed = previous_we.exercise_sets.create!(
        position: 1,
        weight_kg: 60,
        reps: 5,
        completed_at: 2.days.ago + 5.minutes
      )
      later_completed = previous_we.exercise_sets.create!(
        position: 2,
        weight_kg: 47.5,
        reps: 10,
        completed_at: 2.days.ago + 10.minutes
      )

      earlier_completed.update_columns(created_at: Time.current)
      later_completed.update_columns(created_at: 3.days.ago)

      current_workout = user.workouts.create!(gym: gym, started_at: Time.current, finished_at: nil)
      current_block = current_workout.workout_blocks.create!(position: 1, rest_seconds: 90)
      current_we = current_block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)

      expect(helper.last_weight_for(current_we)).to eq('47.5')
      expect(helper.last_reps_for(current_we)).to eq(10)
    end
  end
end

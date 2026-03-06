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
  end
end

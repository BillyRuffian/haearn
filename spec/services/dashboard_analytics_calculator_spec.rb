require 'rails_helper'

RSpec.describe DashboardAnalyticsCalculator do
  describe '#calculate' do
    it 'buckets rep ranges from finished working sets only' do
      user = User.create!(
        email_address: 'analytics-spec@example.com',
        password: 'password',
        password_confirmation: 'password',
        name: 'Analytics Spec User',
        preferred_unit: 'kg'
      )
      gym = user.gyms.create!(name: 'Spec Gym')
      machine = gym.machines.create!(name: 'Spec Machine', equipment_type: 'machine', display_unit: 'kg')
      exercise = user.exercises.create!(
        name: 'Spec Exercise',
        exercise_type: 'reps',
        has_weight: true,
        primary_muscle_group: 'chest'
      )

      workout = user.workouts.create!(gym: gym, started_at: 2.days.ago, finished_at: 2.days.ago + 1.hour)
      block = workout.workout_blocks.create!(position: 1, rest_seconds: 90)
      workout_exercise = block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)

      [
        { position: 1, reps: 3, is_warmup: false },
        { position: 2, reps: 8, is_warmup: false },
        { position: 3, reps: 12, is_warmup: false },
        { position: 4, reps: 20, is_warmup: false },
        { position: 5, reps: 5, is_warmup: true }
      ].each do |attributes|
        workout_exercise.exercise_sets.create!(
          attributes.merge(weight_kg: 40, completed_at: 2.days.ago + attributes[:position].minutes)
        )
      end

      calculator = described_class.new(user: user)

      expect(calculator.calculate('rep_range_distribution')).to eq(
        '1-5' => 1,
        '6-10' => 1,
        '11-15' => 1,
        '16+' => 1
      )
    end

    it 'returns zeroed streak data when the user has no completed workouts' do
      user = User.create!(
        email_address: 'analytics-empty@example.com',
        password: 'password',
        password_confirmation: 'password',
        name: 'Analytics Empty User',
        preferred_unit: 'kg'
      )

      calculator = described_class.new(user: user)

      expect(calculator.calculate('streaks')).to eq(
        current: 0,
        longest: 0,
        last_workout_days_ago: nil
      )
    end
  end
end

require 'rails_helper'

RSpec.describe 'Equipment-free analysis' do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { users(:one) }
  let(:gym) { gyms(:one) }
  let(:exercise) do
    user.exercises.create!(
      name: 'Equipment Free Analysis Press',
      exercise_type: 'reps',
      has_weight: true,
      primary_muscle_group: 'chest'
    )
  end
  let(:machine) { gym.machines.create!(name: 'Analysis Stack', equipment_type: 'machine', display_unit: 'kg') }

  it 'calculates equipment-free PRs independently from machine-backed PRs' do
    equipment_free = create_session(machine: nil, finished_at: 2.days.ago, weight: 80, reps: 5)
    create_session(machine: machine, finished_at: 1.day.ago, weight: 200, reps: 5)

    result = PrCalculator.calculate_all([ equipment_free ], exercise: exercise)

    expect(result.dig(:best_set_weight, :weight_kg)).to eq(80)
    expect(PrCalculator.previous_best_weight(equipment_free)).to be_nil
  end

  it 'keeps dashboard PR chronology separated by nil machine id' do
    travel_to Time.zone.local(2026, 8, 13, 12) do
      create_session(machine: nil, finished_at: 13.months.ago, weight: 80, reps: 5)
      create_session(machine: machine, finished_at: 13.months.ago + 1.day, weight: 200, reps: 5)
      create_session(machine: nil, finished_at: 2.days.ago, weight: 90, reps: 5)

      weight_prs = DashboardAnalyticsCalculator.new(user: user)
        .calculate('pr_timeline')
        .select { |pr| pr[:type] == 'weight' && pr[:exercise] == exercise.name }

      expect(weight_prs).to contain_exactly(hash_including(weight: 90, reps: 5))
    end
  end

  private

  def create_session(machine:, finished_at:, weight:, reps:, rpe: nil)
    started_at = finished_at ? finished_at - 1.hour : Time.current
    workout = user.workouts.create!(gym: gym, started_at:, finished_at:)
    block = workout.workout_blocks.create!(position: 1)
    workout_exercise = block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)
    workout_exercise.exercise_sets.create!(
      position: 1,
      weight_kg: weight,
      reps: reps,
      rpe: rpe,
      is_warmup: false,
      completed_at: finished_at || Time.current
    )
    workout_exercise
  end
end

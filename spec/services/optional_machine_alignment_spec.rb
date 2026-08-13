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

  it 'keeps progression suggestions scoped to equipment-free sessions' do
    travel_to Time.zone.local(2026, 8, 13, 12) do
      create_session(machine: nil, finished_at: 6.days.ago, weight: 60, reps: 10, rpe: 7)
      create_session(machine: machine, finished_at: 5.days.ago, weight: 100, reps: 10, rpe: 7)
      current = create_session(machine: nil, finished_at: nil, weight: 60, reps: 10, rpe: 7)

      expect(ProgressionSuggester.new(workout_exercise: current, user: user).suggest).to be_nil

      create_session(machine: nil, finished_at: 4.days.ago, weight: 60, reps: 10, rpe: 7)
      expect(ProgressionSuggester.new(workout_exercise: current, user: user).suggest).to include(sessions_analyzed: 2)
    end
  end

  it 'keeps readiness and fatigue baselines scoped to equipment-free sessions' do
    travel_to Time.zone.local(2026, 8, 13, 12) do
      create_session(machine: nil, finished_at: 8.days.ago, weight: 60, reps: 10)
      create_session(machine: nil, finished_at: 6.days.ago, weight: 60, reps: 10)
      create_session(machine: machine, finished_at: 5.days.ago, weight: 100, reps: 10)

      checker = ProgressionReadinessChecker.new(exercise: exercise, user: user, machine: nil)
      expect(checker.check_readiness).to be_nil

      create_session(machine: nil, finished_at: 4.days.ago, weight: 60, reps: 10)
      checker = ProgressionReadinessChecker.new(exercise: exercise, user: user, machine: nil)
      expect(checker.check_readiness).to include(sessions_analyzed: 3)

      current = create_session(machine: nil, finished_at: nil, weight: 55, reps: 10)
      fatigue = FatigueAnalyzer.new(workout_exercise: current, user: user).analyze
      expect(fatigue).to include(sessions_analyzed: 3)
    end
  end

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

  it 'builds an exact equipment-free history target for web push' do
    notification = user.notifications.build(
      kind: 'readiness',
      metadata: { exercise_id: exercise.id, machine_id: nil }
    )
    service = WebPushNotificationService.new(user: user)

    expect(service.send(:notification_path, notification)).to eq(
      "/exercises/#{exercise.id}/history?machine_id=none"
    )
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

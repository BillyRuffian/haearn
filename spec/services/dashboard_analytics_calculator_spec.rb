require 'rails_helper'

RSpec.describe DashboardAnalyticsCalculator do
  include ActiveSupport::Testing::TimeHelpers

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

    it 'summarizes tonnage and training time by clear analyzed periods including all time' do
      travel_to Time.zone.local(2026, 8, 11, 12, 0, 0) do
        user = User.create!(
          email_address: 'analytics-tonnage@example.com',
          password: 'password',
          password_confirmation: 'password',
          name: 'Analytics Tonnage User',
          preferred_unit: 'kg'
        )
        gym = user.gyms.create!(name: 'Spec Gym')
        machine = gym.machines.create!(name: 'Spec Machine', equipment_type: 'machine', display_unit: 'kg')
        exercise = user.exercises.create!(
          name: 'Spec Lift',
          exercise_type: 'reps',
          has_weight: true,
          primary_muscle_group: 'back'
        )

        create_workout_set(user:, gym:, machine:, exercise:, finished_at: Time.zone.local(2026, 8, 10, 18), weight_kg: 100, reps: 5)
        create_workout_set(user:, gym:, machine:, exercise:, finished_at: Time.zone.local(2026, 7, 20, 18), weight_kg: 80, reps: 10)
        create_workout_set(user:, gym:, machine:, exercise:, finished_at: Time.zone.local(2026, 5, 20, 18), weight_kg: 60, reps: 10)
        create_workout_set(user:, gym:, machine:, exercise:, finished_at: Time.zone.local(2025, 6, 1, 18), weight_kg: 40, reps: 10)
        create_workout_set(user:, gym:, machine:, exercise:, finished_at: Time.zone.local(2026, 8, 10, 18), weight_kg: 999, reps: 1, is_warmup: true)

        result = described_class.new(user: user).calculate('training_period_totals')

        expect(result).to eq([
          {
            label: 'This week',
            volume: 500,
            duration_minutes: 120,
            duration_label: '2h',
            start_date: '2026-08-10',
            end_date: '2026-08-11',
            range_label: 'Aug 10, 2026 - Aug 11, 2026'
          },
          {
            label: 'Last 30 days',
            volume: 1300,
            duration_minutes: 180,
            duration_label: '3h',
            start_date: '2026-07-13',
            end_date: '2026-08-11',
            range_label: 'Jul 13, 2026 - Aug 11, 2026'
          },
          {
            label: 'Last 90 days',
            volume: 1900,
            duration_minutes: 240,
            duration_label: '4h',
            start_date: '2026-05-14',
            end_date: '2026-08-11',
            range_label: 'May 14, 2026 - Aug 11, 2026'
          },
          {
            label: 'Last 12 months',
            volume: 1900,
            duration_minutes: 240,
            duration_label: '4h',
            start_date: '2025-08-11',
            end_date: '2026-08-11',
            range_label: 'Aug 11, 2025 - Aug 11, 2026'
          },
          {
            label: 'All time',
            volume: 2300,
            duration_minutes: 300,
            duration_label: '5h',
            start_date: '2025-06-01',
            end_date: '2026-08-10',
            range_label: 'Jun 1, 2025 - Aug 10, 2026'
          }
        ])
      end
    end

    it 'does not show training period start dates before the first completed workout' do
      travel_to Time.zone.local(2026, 8, 11, 12, 0, 0) do
        user = User.create!(
          email_address: 'analytics-start-clamp@example.com',
          password: 'password',
          password_confirmation: 'password',
          name: 'Analytics Start Clamp User',
          preferred_unit: 'kg'
        )
        gym = user.gyms.create!(name: 'Spec Gym')
        machine = gym.machines.create!(name: 'Spec Machine', equipment_type: 'machine', display_unit: 'kg')
        exercise = user.exercises.create!(
          name: 'Spec Lift',
          exercise_type: 'reps',
          has_weight: true,
          primary_muscle_group: 'back'
        )

        create_workout_set(user:, gym:, machine:, exercise:, finished_at: Time.zone.local(2026, 8, 1, 18), weight_kg: 50, reps: 10)

        result = described_class.new(user: user).calculate('training_period_totals')

        expect(result.pluck(:start_date)).to eq([
          '2026-08-10',
          '2026-08-01',
          '2026-08-01',
          '2026-08-01',
          '2026-08-01'
        ])
        expect(result.find { |period| period[:label] == 'Last 90 days' }[:range_label]).to eq('Aug 1, 2026 - Aug 11, 2026')
      end
    end

    it 'uses fixed query counts instead of queries per week, workout, exercise, or set' do
      calculator = described_class.new(user: users(:system))
      expected_query_counts = {
        'rep_range_distribution' => 1,
        'workout_frequency' => 1,
        'exercise_frequency' => 1,
        'pr_timeline' => 3,
        'streaks' => 1,
        'week_comparison' => 1,
        'tonnage' => 1,
        'training_period_totals' => 3,
        'plateaus' => 1,
        'training_density' => 1,
        'muscle_group_volume' => 1,
        'muscle_balance' => 1,
        'consistency' => 3
      }

      actual_query_counts = expected_query_counts.each_key.to_h do |key|
        [ key, count_sql_queries { calculator.calculate(key) } ]
      end

      expect(actual_query_counts).to eq(expected_query_counts)
    end

    it 'aggregates weekly tonnage, density, and muscle totals without changing their values' do
      travel_to Time.zone.local(2026, 8, 13, 12, 0, 0) do
        user = User.create!(
          email_address: 'analytics-grouped@example.com',
          password: 'password',
          password_confirmation: 'password',
          name: 'Grouped Analytics User',
          preferred_unit: 'kg'
        )
        gym = user.gyms.create!(name: 'Grouped Gym')
        machine = gym.machines.create!(name: 'Grouped Machine', equipment_type: 'machine', display_unit: 'kg')
        chest = user.exercises.create!(name: 'Grouped Press', exercise_type: 'reps', has_weight: true, primary_muscle_group: 'chest')
        back = user.exercises.create!(name: 'Grouped Row', exercise_type: 'reps', has_weight: true, primary_muscle_group: 'back')

        recent_workout = create_workout_set(
          user:, gym:, machine:, exercise: chest,
          finished_at: Time.zone.local(2026, 8, 12, 18), weight_kg: 100, reps: 5
        )
        recent_workout.workout_exercises.first.exercise_sets.create!(
          position: 2, weight_kg: 50, reps: 10, is_warmup: false,
          completed_at: recent_workout.finished_at - 20.minutes
        )
        create_workout_set(
          user:, gym:, machine:, exercise: back,
          finished_at: Time.zone.local(2026, 8, 5, 18), weight_kg: 40, reps: 10
        )

        calculator = described_class.new(user: user)
        tonnage = calculator.calculate('tonnage')
        density = calculator.calculate('training_density')
        muscles = calculator.calculate('muscle_group_volume')
        balance = calculator.calculate('muscle_balance').index_by { |entry| entry[:muscle] }

        expect(tonnage.last(2).pluck(:volume)).to eq([ 400, 1000 ])
        expect(density.last).to include(volume: 1000, duration: 60, density: 17, gym: 'Grouped Gym')
        expect(muscles.fetch('chest')).to include(volume: 1000, sets: 2, days_since: 1)
        expect(balance.fetch('Chest')).to include(raw_volume: 1000, value: 100)
        expect(balance.fetch('Back')).to include(raw_volume: 400, value: 40)
      end
    end

    it 'compares weeks using working sets while retaining completed workouts without sets' do
      travel_to Time.zone.local(2026, 8, 13, 12, 0, 0) do
        user, gym, machine, exercise = create_analytics_context('week-comparison')
        this_week = create_workout_set(
          user:, gym:, machine:, exercise:,
          finished_at: Time.zone.local(2026, 8, 12, 18), weight_kg: 50, reps: 10
        )
        this_week.workout_exercises.first.exercise_sets.create!(
          position: 2, weight_kg: 200, reps: 10, is_warmup: true,
          completed_at: this_week.finished_at - 20.minutes
        )
        create_workout_set(
          user:, gym:, machine:, exercise:,
          finished_at: Time.zone.local(2026, 8, 5, 18), weight_kg: 100, reps: 5
        )
        user.workouts.create!(
          gym:, started_at: Time.zone.local(2026, 8, 11, 18),
          finished_at: Time.zone.local(2026, 8, 11, 19)
        )

        result = described_class.new(user: user).calculate('week_comparison')

        expect(result).to eq(
          this_week: { volume: 500, workouts: 2, sets: 1 },
          last_week: { volume: 500, workouts: 1, sets: 1 }
        )
      end
    end

    it 'seeds recent PR progression from grouped historical bests' do
      travel_to Time.zone.local(2026, 8, 13, 12, 0, 0) do
        user, gym, machine, exercise = create_analytics_context('pr-history')
        create_workout_set(
          user:, gym:, machine:, exercise:,
          finished_at: Time.zone.local(2025, 1, 10, 18), weight_kg: 100, reps: 5
        )
        create_workout_set(
          user:, gym:, machine:, exercise:,
          finished_at: Time.zone.local(2026, 2, 10, 18), weight_kg: 90, reps: 10
        )
        create_workout_set(
          user:, gym:, machine:, exercise:,
          finished_at: Time.zone.local(2026, 3, 10, 18), weight_kg: 110, reps: 4
        )

        result = described_class.new(user: user).calculate('pr_timeline')

        expect(result).to contain_exactly(
          hash_including(date: '2026-02-10', weight: 90, reps: 10, type: 'volume'),
          hash_including(date: '2026-03-10', weight: 110, reps: 4, type: 'weight')
        )
      end
    end

    it 'detects plateaus from all-time progression for recently active exercises' do
      travel_to Time.zone.local(2026, 8, 13, 12, 0, 0) do
        user, gym, machine, exercise = create_analytics_context('plateau-history')
        create_workout_set(
          user:, gym:, machine:, exercise:,
          finished_at: Time.zone.local(2025, 1, 10, 18), weight_kg: 100, reps: 5
        )
        create_workout_set(
          user:, gym:, machine:, exercise:,
          finished_at: Time.zone.local(2025, 3, 10, 18), weight_kg: 90, reps: 5
        )
        create_workout_set(
          user:, gym:, machine:, exercise:,
          finished_at: Time.zone.local(2026, 7, 30, 18), weight_kg: 80, reps: 5
        )

        result = described_class.new(user: user).calculate('plateaus')

        expect(result).to contain_exactly(
          exercise: exercise.name,
          weeks_since_pr: 82,
          best_weight: 100,
          last_pr_date: 'Jan 10'
        )
      end
    end
  end

  def create_analytics_context(identifier)
    user = User.create!(
      email_address: "analytics-#{identifier}@example.com",
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

    [ user, gym, machine, exercise ]
  end

  def create_workout_set(user:, gym:, machine:, exercise:, finished_at:, weight_kg:, reps:, is_warmup: false)
    workout = user.workouts.create!(
      gym: gym,
      started_at: finished_at - 1.hour,
      finished_at: finished_at
    )
    block = workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    workout_exercise = block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)
    workout_exercise.exercise_sets.create!(
      position: 1,
      weight_kg: weight_kg,
      reps: reps,
      is_warmup: is_warmup,
      completed_at: finished_at - 30.minutes
    )
    workout
  end

  def count_sql_queries
    count = 0
    callback = lambda do |_name, _started, _finished, _unique_id, payload|
      next if payload[:cached]
      next if payload[:name].in?(%w[SCHEMA TRANSACTION])
      next if payload[:sql].match?(/\A(?:BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/)

      count += 1
    end

    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
      ActiveRecord::Base.uncached { yield }
    end

    count
  end
end

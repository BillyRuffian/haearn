require 'rails_helper'

RSpec.describe WeeklySummaryCalculator do
  include ActiveSupport::Testing::TimeHelpers

  around do |example|
    travel_to(Time.zone.local(2026, 8, 30, 12)) { example.run }
  end

  let(:user) do
    User.create!(
      name: 'Weekly Summary User',
      email_address: 'weekly-summary-spec@example.com',
      password: 'password',
      preferred_unit: 'kg'
    )
  end
  let(:gym) { user.gyms.create!(name: 'Weekly Summary Gym') }
  let(:exercise) do
    user.exercises.create!(
      name: 'Weekly Summary Lift',
      exercise_type: 'reps',
      has_weight: true,
      primary_muscle_group: 'back'
    )
  end
  let(:week_start) { Time.zone.local(2026, 8, 17) }

  it 'uses the available calendar weeks and unrounded averages for percentage changes' do
    create_workout(finished_at: Time.zone.local(2026, 8, 3, 19), duration_minutes: 60, sets: [ [ 100, 10 ] ])
    create_workout(finished_at: Time.zone.local(2026, 8, 4, 19), duration_minutes: 30, sets: [ [ 50, 10 ], [ 50, 10 ] ])

    3.times do |index|
      create_workout(
        finished_at: Time.zone.local(2026, 8, 18 + index, 19),
        duration_minutes: 45,
        sets: [ [ 100, 10 ] ]
      )
    end

    comparison = described_class.new(user:, week_start:).calculate.fetch(:vs_average)

    expect(comparison).to include(
      baseline_weeks: 2,
      avg_workout_count: 1.0,
      avg_volume_kg: 1_000.0,
      avg_sets: 1.5,
      avg_duration_minutes: 45.0,
      workout_count_pct: 200,
      volume_pct: 200,
      sets_pct: 100,
      duration_pct: 200
    )
  end

  it 'includes inactive weeks after the first historical workout in the baseline' do
    create_workout(finished_at: Time.zone.local(2026, 7, 27, 19), sets: [ [ 100, 10 ] ])
    create_workout(finished_at: Time.zone.local(2026, 8, 18, 19), sets: [ [ 100, 10 ] ])

    comparison = described_class.new(user:, week_start:).calculate.fetch(:vs_average)

    expect(comparison[:baseline_weeks]).to eq(3)
    expect(comparison[:avg_workout_count]).to eq(0.3)
    expect(comparison[:workout_count_pct]).to eq(200)
  end

  it 'does not report a percentage when the historical metric is zero' do
    create_workout(finished_at: Time.zone.local(2026, 8, 10, 19), sets: [ [ nil, nil ] ])
    create_workout(finished_at: Time.zone.local(2026, 8, 18, 19), sets: [ [ 100, 10 ] ])

    comparison = described_class.new(user:, week_start:).calculate.fetch(:vs_average)

    expect(comparison[:volume_pct]).to be_nil
    expect(comparison[:workout_count_pct]).to eq(0)
  end

  it 'omits comparisons when no earlier completed workout exists' do
    create_workout(finished_at: Time.zone.local(2026, 8, 18, 19), sets: [ [ 100, 10 ] ])

    summary = described_class.new(user:, week_start:).calculate

    expect(summary[:vs_average]).to be_nil
  end

  private

  def create_workout(finished_at:, duration_minutes: 45, sets:)
    workout = user.workouts.create!(
      gym: gym,
      started_at: finished_at - duration_minutes.minutes,
      finished_at: finished_at
    )
    block = workout.workout_blocks.create!(position: 1)
    workout_exercise = block.workout_exercises.create!(exercise: exercise, position: 1)

    sets.each_with_index do |(weight, reps), index|
      workout_exercise.exercise_sets.create!(
        position: index + 1,
        weight_kg: weight,
        reps: reps,
        is_warmup: false,
        completed_at: finished_at - 5.minutes
      )
    end

    workout
  end
end

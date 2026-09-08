require 'rails_helper'

RSpec.describe StrengthAnalyticsCalculator do
  def build_user(email:)
    User.create!(
      email_address: email,
      password: 'password',
      password_confirmation: 'password',
      name: 'Strength Analytics User',
      preferred_unit: 'kg'
    )
  end

  def create_lift_set(user:, gym:, exercise:, finished_at:, weight_kg:)
    workout = user.workouts.create!(gym: gym, started_at: finished_at - 1.hour, finished_at: finished_at)
    block = workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    workout_exercise = block.workout_exercises.create!(exercise: exercise, machine: nil, position: 1)
    workout_exercise.exercise_sets.create!(
      position: 1,
      reps: 1,
      weight_kg: weight_kg,
      is_warmup: false,
      completed_at: finished_at - 5.minutes
    )
  end

  it 'pairs each best lift with its latest prior weigh-in within 30 days' do
    user = build_user(email: 'lift-ratio-pairing@example.com')
    gym = user.gyms.create!(name: 'Strength Gym')
    squat = user.exercises.create!(
      name: 'Ratio Squat', exercise_type: 'reps', has_weight: true,
      primary_muscle_group: 'quadriceps', strength_lift_key: 'squat'
    )
    bench = user.exercises.create!(
      name: 'Ratio Bench', exercise_type: 'reps', has_weight: true,
      primary_muscle_group: 'chest', strength_lift_key: 'bench'
    )

    user.body_metrics.create!(measured_at: 31.days.ago, weight_kg: 80)
    user.body_metrics.create!(measured_at: 11.days.ago, weight_kg: 100)
    user.body_metrics.create!(measured_at: Time.current, weight_kg: 50)
    create_lift_set(user: user, gym: gym, exercise: squat, finished_at: 30.days.ago, weight_kg: 100)
    create_lift_set(user: user, gym: gym, exercise: bench, finished_at: 10.days.ago, weight_kg: 80)

    result = described_class.new(user: user).lift_ratios

    expect(result[:values]).to eq([ 1.25, 0.8, nil, nil ])
    expect(result.dig(:details, 'squat')).to include(bodyweight_kg: 80.0, ratio: 1.25)
    expect(result.dig(:details, 'bench')).to include(bodyweight_kg: 100.0, ratio: 0.8)
    expect(result[:reason]).to be_nil
  end

  it 'omits a lift when no bodyweight precedes its session within 30 days' do
    user = build_user(email: 'lift-ratio-stale@example.com')
    gym = user.gyms.create!(name: 'Strength Gym')
    squat = user.exercises.create!(
      name: 'Unpaired Squat', exercise_type: 'reps', has_weight: true,
      primary_muscle_group: 'quadriceps', strength_lift_key: 'squat'
    )

    user.body_metrics.create!(measured_at: Time.current, weight_kg: 80)
    create_lift_set(user: user, gym: gym, exercise: squat, finished_at: 40.days.ago, weight_kg: 100)

    result = described_class.new(user: user).lift_ratios

    expect(result[:values]).to be_empty
    expect(result[:reason]).to include('on or before that session within 30 days')
  end
end

require 'rails_helper'

RSpec.describe WorkoutExercise, type: :model do
  let(:user) { users(:one) }
  let(:gym) { gyms(:one) }
  let(:exercise) { exercises(:one) }
  let(:machine) { machines(:one) }

  it 'uses the latest setful session when a newer matching exercise was skipped' do
    recorded = add_workout_exercise(started_at: 5.days.ago, persistent_notes: 'Seat 4')
    recorded.exercise_sets.create!(
      position: 1,
      weight_kg: 50,
      reps: 8,
      completed_at: 5.days.ago + 10.minutes
    )

    skipped = add_workout_exercise(started_at: 2.days.ago, persistent_notes: 'Skipped')
    current = add_workout_exercise(started_at: Time.current, finished_at: nil)

    expect(current.previous_workout_exercise).to eq(recorded)
    expect(current.previous_workout_exercise).not_to eq(skipped)
  end

  it 'includes warmup-only exercises once and excludes exercises with no sets' do
    warmup_only = add_workout_exercise(started_at: 3.days.ago)
    2.times do |position|
      warmup_only.exercise_sets.create!(
        position: position + 1,
        weight_kg: 20,
        reps: 10,
        is_warmup: true,
        completed_at: 3.days.ago + (position + 1).minutes
      )
    end
    setless = add_workout_exercise(started_at: 2.days.ago)

    expect(described_class.with_recorded_sets).to include(warmup_only)
    expect(described_class.with_recorded_sets.where(id: warmup_only.id).count).to eq(1)
    expect(described_class.with_recorded_sets).not_to include(setless)
  end

  private

  def add_workout_exercise(started_at:, finished_at: started_at + 45.minutes, persistent_notes: nil)
    workout = user.workouts.create!(gym:, started_at:, finished_at:)
    block = workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    block.workout_exercises.create!(exercise:, machine:, position: 1, persistent_notes:)
  end
end

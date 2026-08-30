require 'rails_helper'

RSpec.describe 'Single active workout', type: :request do
  let(:user) { users(:one) }
  let(:gym) { gyms(:one) }

  before do
    sign_in_as(user)
    user.workouts.in_progress.destroy_all
  end

  it 'returns new and create attempts to the existing active workout' do
    active_workout = user.workouts.create!(gym:, started_at: 30.minutes.ago)

    get new_workout_path

    expect(response).to redirect_to(workout_path(active_workout))

    expect do
      post workouts_path, params: { workout: { gym_id: gym.id } }
    end.not_to change(user.workouts, :count)
    expect(response).to redirect_to(workout_path(active_workout))
    expect(user.workouts.in_progress).to contain_exactly(active_workout)
  end

  it 'returns copy and continue attempts to the existing active workout' do
    source = user.workouts.create!(gym:, started_at: 2.days.ago, finished_at: 2.days.ago + 45.minutes)
    recently_finished = user.workouts.create!(gym:, started_at: 40.minutes.ago, finished_at: 10.minutes.ago)
    active_workout = user.workouts.create!(gym:, started_at: 5.minutes.ago)

    expect do
      post copy_workout_path(source)
    end.not_to change(user.workouts, :count)
    expect(response).to redirect_to(workout_path(active_workout))

    patch continue_workout_path(recently_finished)

    expect(response).to redirect_to(workout_path(active_workout))
    expect(recently_finished.reload).to be_completed
    expect(user.workouts.in_progress).to contain_exactly(active_workout)
  end

  it 'appends a launched template to the active workout without creating another workout' do
    existing_exercise = exercises(:one)
    active_workout = user.workouts.create!(gym:, started_at: 30.minutes.ago)
    existing_block = active_workout.workout_blocks.create!(position: 1, rest_seconds: 60)
    existing_block.workout_exercises.create!(exercise: existing_exercise, position: 1)

    template = user.workout_templates.create!(name: 'Upper Builder')
    first_template_block = template.template_blocks.create!(position: 1, rest_seconds: 90)
    first_template_exercise = first_template_block.template_exercises.create!(
      exercise: exercises(:bench_press),
      persistent_notes: 'Pause on the chest'
    )
    second_template_block = template.template_blocks.create!(position: 2, rest_seconds: 120)
    second_template_exercises = [
      second_template_block.template_exercises.create!(exercise: exercises(:one)),
      second_template_block.template_exercises.create!(exercise: exercises(:bench_press))
    ]

    expect do
      post start_workout_workout_template_path(template)
    end.not_to change(user.workouts, :count)

    expect(response).to redirect_to(workout_path(active_workout))
    expect(user.workouts.in_progress).to contain_exactly(active_workout)
    expect(active_workout.reload.workout_blocks.ordered.pluck(:position, :rest_seconds)).to eq(
      [ [ 1, 60 ], [ 2, 90 ], [ 3, 120 ] ]
    )

    appended_blocks = active_workout.workout_blocks.ordered.last(2)
    expect(appended_blocks.first.workout_exercises.sole).to have_attributes(
      template_exercise_id: first_template_exercise.id,
      persistent_notes: 'Pause on the chest'
    )
    expect(appended_blocks.second.workout_exercises.order(:position).pluck(:template_exercise_id)).to eq(
      second_template_exercises.map(&:id)
    )
  end

  it 'creates a single active workout when launching a template without one' do
    user.update!(default_gym: gym)
    template = user.workout_templates.create!(name: 'Fresh Template')
    block = template.template_blocks.create!(position: 1)
    block.template_exercises.create!(exercise: exercises(:bench_press))

    expect do
      post start_workout_workout_template_path(template)
    end.to change(user.workouts, :count).by(1)

    workout = user.workouts.in_progress.sole
    expect(response).to redirect_to(workout_path(workout))
    expect(workout.workout_exercises.sole.template_exercise).to eq(template.template_exercises.sole)
  end
end

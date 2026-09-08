require 'rails_helper'

RSpec.describe 'Template exercise removal', type: :request do
  let(:user) { users(:one) }
  let(:template) { workout_templates(:one) }
  let!(:template_block) { template.template_blocks.create!(position: 1) }
  let!(:template_exercise) do
    template_block.template_exercises.create!(exercise: exercises(:one), target_sets: 3, target_reps: 8)
  end
  let!(:historical_workout_exercise) do
    workout_blocks(:one).workout_exercises.create!(
      exercise: exercises(:one),
      template_exercise: template_exercise,
      position: 2
    )
  end

  before { sign_in_as(user) }

  it 'removes the exercise from the template while retaining historical workout links' do
    expect do
      delete workout_template_template_exercise_path(template, template_exercise)
    end.not_to change(TemplateExercise, :count)

    expect(response).to redirect_to(workout_template_path(template))
    expect(flash[:notice]).to eq('Exercise removed from template.')
    expect(template_exercise.reload.removed_at).to be_present
    expect(template_block.reload.template_exercises).to be_empty
    expect(historical_workout_exercise.reload.template_exercise).to eq(template_exercise)

    get workout_template_path(template)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Archived Exercises')
    expect(response.body).to include(exercises(:one).name)
    expect(response.body).to include(restore_workout_template_template_exercise_path(template, template_exercise))
  end

  it 'restores an archived exercise without replacing its historical link' do
    delete workout_template_template_exercise_path(template, template_exercise)

    expect do
      patch restore_workout_template_template_exercise_path(template, template_exercise)
    end.not_to change(TemplateExercise, :count)

    expect(response).to redirect_to(workout_template_path(template))
    expect(template_exercise.reload.removed_at).to be_nil
    expect(template_block.reload.template_exercises).to contain_exactly(template_exercise)
    expect(historical_workout_exercise.reload.template_exercise).to eq(template_exercise)
  end
end

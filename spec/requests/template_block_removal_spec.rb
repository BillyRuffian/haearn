require 'rails_helper'

RSpec.describe 'Template block removal', type: :request do
  let(:user) { users(:one) }
  let(:template) { workout_templates(:one) }
  let!(:block) { template.template_blocks.create!(position: 1) }
  let!(:exercise) { block.template_exercises.create!(exercise: exercises(:one), target_sets: 3) }
  let!(:archived_exercise) do
    block.all_template_exercises.create!(exercise: exercises(:two), removed_at: 1.day.ago)
  end
  let!(:history) do
    workout_blocks(:one).workout_exercises.create!(exercise: exercise.exercise, template_exercise: exercise)
  end
  let!(:remaining_block) { template.template_blocks.create!(position: 2) }
  let!(:remaining_exercise) { remaining_block.template_exercises.create!(exercise: exercises(:two)) }

  before { sign_in_as(user) }

  it 'removes the whole block from the template and future workouts while preserving history' do
    archived_at = archived_exercise.removed_at
    delete workout_template_template_block_path(template, block)

    expect(response).to redirect_to(workout_template_path(template))
    expect(flash[:notice]).to eq('Block removed from template.')
    expect(template.reload.template_blocks).to contain_exactly(remaining_block)
    expect(template.template_exercises).to contain_exactly(remaining_exercise)
    expect(exercise.reload.removed_at).to be_present
    expect(archived_exercise.reload.removed_at).to eq(archived_at)
    expect(history.reload.template_exercise).to eq(exercise)

    get workout_template_path(template)
    expect(response.body).not_to include("data-block-id=\"#{block.id}\"")
    expect(response.body).to include(restore_workout_template_template_exercise_path(template, exercise))

    get new_workout_template_template_exercise_path(template)
    options = Nokogiri::HTML5(response.body).css('#template_exercise_block_id option')
    expect(options.map { |option| option['value'] }).not_to include(block.id.to_s)

    prescription = ProgramPrescription.new(program_session: ProgramSession.new(workout_template: template.reload))
    expect(prescription.rows.pluck('template_exercise_id')).to eq([ remaining_exercise.id ])

    user.update!(default_gym: gyms(:one))
    post start_workout_workout_template_path(template)
    destination = user.active_workout
    expect(response).to redirect_to(workout_path(destination))
    expect(destination.workout_blocks.count).to eq(1)
    expect(destination.workout_exercises.where(template_exercise: exercise)).not_to exist
    expect(destination.workout_exercises.where(template_exercise: remaining_exercise)).to exist
  end

  it 'restores only the selected exercise and its original block' do
    delete workout_template_template_block_path(template, block)
    patch restore_workout_template_template_exercise_path(template, exercise)

    expect(flash[:notice]).to eq('Exercise restored to template.')
    expect(template.reload.template_blocks).to contain_exactly(block, remaining_block)
    expect(block.reload.template_exercises).to contain_exactly(exercise)
    expect(archived_exercise.reload.removed_at).to be_present
    expect(history.reload.template_exercise).to eq(exercise)
  end

  it 'removes an empty block and an unused block' do
    empty_block = template.template_blocks.create!(position: 3)
    [ empty_block, remaining_block ].each do |unused_block|
      delete workout_template_template_block_path(template, unused_block)
      expect(flash[:notice]).to eq('Block removed from template.')
      expect(template.reload.template_blocks).not_to include(unused_block)
    end
    expect(remaining_exercise.reload.removed_at).to be_present
  end

  it 'rolls back exercise removal if the block cannot be archived' do
    block.update_column(:position, -1)
    delete workout_template_template_block_path(template, block)

    expect(flash[:alert]).to be_present
    expect(block.reload.removed_at).to be_nil
    expect(exercise.reload.removed_at).to be_nil
    expect(history.reload.template_exercise).to eq(exercise)
  end

  it 'does not allow another user to remove a block' do
    sign_in_as(users(:two))
    delete workout_template_template_block_path(template, block)

    expect(response).to have_http_status(:not_found)
    expect(block.reload.removed_at).to be_nil
    expect(exercise.reload.removed_at).to be_nil
  end

  it 'does not allow a block from another template to be removed through this template' do
    other_template = user.workout_templates.create!(name: 'Other template')
    delete workout_template_template_block_path(other_template, block)

    expect(response).to have_http_status(:not_found)
    expect(block.reload.removed_at).to be_nil
  end

  it 'still deletes unused templates including their archived blocks' do
    unused_template = user.workout_templates.create!(name: 'Unused')
    unused_block = unused_template.template_blocks.create!(position: 1)
    unused_exercise = unused_block.template_exercises.create!(exercise: exercises(:one))
    delete workout_template_template_block_path(unused_template, unused_block)
    delete workout_template_path(unused_template)

    expect(response).to redirect_to(workout_templates_path)
    expect(TemplateBlock.exists?(unused_block.id)).to be(false)
    expect(TemplateExercise.exists?(unused_exercise.id)).to be(false)
  end
end

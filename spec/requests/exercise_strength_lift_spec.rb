require 'rails_helper'

RSpec.describe 'Exercise strength lift selection', type: :request do
  let(:user) { users(:one) }
  let(:attributes) do
    { name: 'Accessory curl', exercise_type: 'reps', has_weight: '1', primary_muscle_group: 'biceps', strength_lift_key: '' }
  end

  before { sign_in_as(user) }

  it 'creates an exercise with the Not a major lift form option' do
    get new_exercise_path
    option = Nokogiri::HTML(response.body).at_css('select[name="exercise[strength_lift_key]"] option[value=""]')
    expect(option.text).to eq('Not a major lift')

    expect do
      post exercises_path, params: { exercise: attributes.merge(strength_lift_key: option['value']) }
    end.to change(user.exercises, :count).by(1)

    expect(response).to redirect_to(exercises_path)
    expect(user.exercises.find_by!(name: attributes[:name]).strength_lift_key).to be_nil
  end

  it 'creates an unclassified exercise through the Turbo form' do
    expect do
      post exercises_path, params: { exercise: attributes }, headers: { 'ACCEPT' => Mime[:turbo_stream].to_s }
    end.to change(user.exercises, :count).by(1)

    expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
    expect(response.body).to include('action="prepend" target="exercises"')
    expect(user.exercises.find_by!(name: attributes[:name]).strength_lift_key).to be_nil
  end

  it 'clears an existing major lift classification when the blank option is selected' do
    exercise = user.exercises.create!(attributes.merge(name: 'Press variation', strength_lift_key: 'bench'))

    patch exercise_path(exercise), params: { exercise: { strength_lift_key: '' } }

    expect(response).to redirect_to(exercises_path)
    expect(exercise.reload.strength_lift_key).to be_nil
  end

  it 'preserves an explicitly selected major lift' do
    post exercises_path, params: { exercise: attributes.merge(name: 'Squat variation', strength_lift_key: 'squat') }

    expect(response).to redirect_to(exercises_path)
    expect(user.exercises.find_by!(name: 'Squat variation').strength_lift_key).to eq('squat')
  end

  it 'still rejects an unknown nonblank major lift key' do
    expect do
      post exercises_path, params: { exercise: attributes.merge(strength_lift_key: 'unknown') }
    end.not_to change(Exercise, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('Strength lift key is not included in the list')
  end

  context 'as an administrator' do
    let(:user) { users(:admin) }

    it 'creates a global exercise with a blank major lift classification' do
      expect do
        post admin_exercises_path, params: { exercise: attributes }
      end.to change(Exercise.global, :count).by(1)

      exercise = Exercise.global.find_by!(name: attributes[:name])
      expect(response).to redirect_to(admin_exercise_path(exercise))
      expect(exercise.strength_lift_key).to be_nil
    end
  end
end

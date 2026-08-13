require 'rails_helper'

RSpec.describe 'Optional workout equipment', type: :request do
  let(:user) { users(:one) }
  let(:gym) { gyms(:one) }
  let(:exercise) do
    user.exercises.create!(
      name: 'Equipment Free Press',
      exercise_type: 'reps',
      has_weight: true,
      primary_muscle_group: 'chest'
    )
  end

  before do
    sign_in_as(user)
  end

  it 'adds an equipment-free exercise and replays its offline set idempotently' do
    workout = user.workouts.create!(gym: gym, started_at: Time.current)

    get add_exercise_workout_path(workout, select_exercise: exercise.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('No equipment')

    expect do
      post add_exercise_workout_path(workout), params: { exercise_id: exercise.id }
    end.to change(workout.workout_exercises, :count).by(1)

    workout_exercise = workout.workout_exercises.order(:id).last
    expect(workout_exercise.machine).to be_nil

    set_params = {
      exercise_set: {
        client_request_id: '877ac84a-a11b-4d78-805c-60e40564ded7',
        weight_value: '80',
        reps: '5',
        is_warmup: '0'
      }
    }

    2.times do
      post workout_workout_exercise_exercise_sets_path(workout, workout_exercise), params: set_params
      expect(response).to redirect_to(workout_path(workout))
    end

    expect(workout_exercise.exercise_sets.where(client_request_id: set_params[:exercise_set][:client_request_id]).count).to eq(1)

    get workout_path(workout)
    expect(response.body).to include(history_exercise_path(exercise, machine_id: 'none'))

    get export_data_settings_path
    exported_workout = JSON.parse(response.body).fetch('workouts').find { |entry| entry['started_at'] == workout.started_at.iso8601 }
    expect(exported_workout.dig('blocks', 0, 'exercises', 0, 'machine')).to be_nil
  end

  it 'swaps to an equipment-free exercise while preserving sets and exact-context notes' do
    previous = create_workout(finished_at: 2.days.ago)
    previous_we = add_workout_exercise(previous, machine: nil, persistent_notes: 'Use a controlled pause')
    previous_we.exercise_sets.create!(position: 1, weight_kg: 70, reps: 8, is_warmup: false, completed_at: previous.finished_at)

    workout = create_workout
    machine = gym.machines.create!(name: 'Swap Stack', equipment_type: 'machine', display_unit: 'kg')
    workout_exercise = add_workout_exercise(workout, machine:, persistent_notes: 'Old setup', session_notes: 'Keep this note')
    logged_set = workout_exercise.exercise_sets.create!(position: 1, weight_kg: 75, reps: 8, is_warmup: false)

    get swap_exercise_workout_workout_exercise_path(workout, workout_exercise, select_exercise: exercise.id)
    expect(response.body).to include('No equipment')

    post swap_exercise_workout_workout_exercise_path(workout, workout_exercise), params: { exercise_id: exercise.id }

    expect(response).to redirect_to(workout_path(workout))
    expect(workout_exercise.reload).to have_attributes(
      machine_id: nil,
      session_notes: 'Keep this note',
      persistent_notes: 'Use a controlled pause'
    )
    expect(workout_exercise.exercise_sets).to contain_exactly(logged_set)
  end

  it 'preserves equipment-free exercises through workout copies and templates' do
    source = create_workout(finished_at: 1.day.ago)
    source_exercise = add_workout_exercise(source, machine: nil, persistent_notes: 'No rack needed')
    source_exercise.exercise_sets.create!(position: 1, weight_kg: 50, reps: 10, is_warmup: false, completed_at: source.finished_at)

    post copy_workout_path(source)

    copied_workout = user.workouts.order(:id).last
    expect(response).to redirect_to(workout_path(copied_workout))
    expect(copied_workout.workout_exercises.sole).to have_attributes(machine_id: nil, persistent_notes: 'No rack needed')

    post save_workout_as_template_path(source), params: { name: 'Equipment Free Template' }
    template = user.workout_templates.find_by!(name: 'Equipment Free Template')
    expect(template.template_exercises.sole.machine_id).to be_nil

    user.update!(default_gym: gym)
    post start_workout_workout_template_path(template)
    templated_workout = user.workouts.order(:id).last
    expect(response).to redirect_to(workout_path(templated_workout))
    expect(templated_workout.workout_exercises.sole).to have_attributes(machine_id: nil, persistent_notes: 'No rack needed')
  end

  it 'opens equipment-free history on its own tab without hiding machine history' do
    equipment_free_workout = create_workout(finished_at: 2.days.ago)
    add_workout_exercise(equipment_free_workout, machine: nil)
    machine = gym.machines.create!(name: 'History Stack', equipment_type: 'machine', display_unit: 'kg')
    machine_workout = create_workout(finished_at: 1.day.ago)
    add_workout_exercise(machine_workout, machine: machine)

    get history_exercise_path(exercise, machine_id: 'none')

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML.parse(response.body)
    expect(page.at_css("button[data-bs-target='#no-machine']")['class']).to include('active')
    expect(response.body).to include('Viewing equipment tab:')
    expect(response.body).to include('No Equipment')
    expect(response.body).to include('History Stack')
  end

  it 'links equipment-free readiness notifications to the no-equipment history tab' do
    notification = user.notifications.create!(
      kind: 'readiness',
      severity: 'success',
      title: 'Equipment Free Ready',
      message: 'Ready to progress without equipment.',
      dedupe_key: 'equipment-free-readiness-link',
      metadata: { exercise_id: exercise.id, machine_id: nil }
    )

    get feed_notifications_path, as: :json

    payload = response.parsed_body.fetch('notifications').find { |entry| entry['id'] == notification.id }
    expect(payload.fetch('action_url')).to eq(history_exercise_path(exercise, machine_id: 'none'))
  end

  private

  def create_workout(finished_at: nil)
    started_at = finished_at ? finished_at - 1.hour : Time.current
    user.workouts.create!(gym: gym, started_at:, finished_at:)
  end

  def add_workout_exercise(workout, machine:, persistent_notes: nil, session_notes: nil)
    block = workout.workout_blocks.create!(position: 1)
    block.workout_exercises.create!(
      exercise: exercise,
      machine: machine,
      position: 1,
      persistent_notes: persistent_notes,
      session_notes: session_notes
    )
  end
end

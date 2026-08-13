require 'rails_helper'

RSpec.describe 'Program Builder and Today’s Session', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { users(:one) }
  let(:gym) { gyms(:one) }
  let(:template) do
    workout_template = user.workout_templates.create!(name: 'Monday Strength')
    block = workout_template.template_blocks.create!(position: 1)
    block.template_exercises.create!(
      exercise: exercises(:bench_press),
      target_sets: 4,
      target_reps: 5,
      target_weight_kg: 100,
      persistent_notes: 'Pause every rep'
    )
    workout_template
  end

  before do
    sign_in_as(user)
    user.workouts.in_progress.destroy_all
  end

  around do |example|
    travel_to(Time.zone.local(2026, 8, 10, 9, 0, 0)) { example.run }
  end

  it 'builds and activates a program, then renders its prescribed session' do
    post training_programs_path, params: {
      training_program: { name: 'Strength Block', description: 'Primary block', weeks_count: 4 }
    }
    program = user.training_programs.find_by!(name: 'Strength Block')
    expect(response).to redirect_to(training_program_path(program))

    post training_program_program_sessions_path(program), params: {
      program_session: {
        workout_template_id: template.id,
        name: 'Heavy Monday',
        week_number: 1,
        weekday: 1,
        volume_percent: 50,
        intensity_percent: 90
      }
    }
    program_session = program.program_sessions.sole
    expect(response).to redirect_to(training_program_path(program))

    post activate_training_program_path(program), params: { program_cycle: { starts_on: '2026-08-10' } }
    expect(response).to redirect_to(today_session_path)

    get today_session_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Heavy Monday', '2 × 5', '90 kg')

    get root_path
    expect(response.body).to include('Heavy Monday', 'Open Today')

    expect(program_session.day_name).to eq('Monday')
  end

  it 'starts an adjusted prescription, tracks exercise progress, and records adherence on finish' do
    program, program_session = active_program

    post start_today_session_path(program_session), params: {
      program_session_execution: {
        gym_id: gym.id,
        volume_percent: 50,
        intensity_percent: 90,
        adjustment_reason: 'fatigue',
        adjustment_notes: 'Short sleep'
      }
    }

    execution = program.program_cycles.active.sole.program_session_executions.sole
    workout = execution.workout
    expect(response).to redirect_to(workout_path(workout))
    expect(execution).to have_attributes(
      status: 'in_progress',
      prescribed_sets: 2,
      prescribed_volume_kg: 900.to_d,
      adjustment_reason: 'fatigue'
    )
    expect(execution.prescription.sole).to include('target_sets' => 2, 'target_weight_kg' => 90.0)
    expect(workout.workout_exercises.sole.template_exercise_id).to eq(template.template_exercises.sole.id)

    program_session.update!(name: 'Renamed Later')
    expect(execution.reload.display_name).to eq('Heavy Monday')

    template_exercise = template.template_exercises.sole
    delete training_program_program_session_path(program, program_session)
    expect(program.program_sessions.where(id: program_session.id)).to exist

    delete workout_template_template_exercise_path(template, template_exercise)
    expect(template.template_exercises.where(id: template_exercise.id)).to exist

    get workout_path(workout)
    expect(response.body).to include('Prescribed', '2 × 5', '@ 90 kg')

    workout_exercise = workout.workout_exercises.sole
    2.times do |index|
      workout_exercise.exercise_sets.create!(
        position: index + 1,
        weight_kg: 90,
        reps: 5,
        is_warmup: false,
        completed_at: Time.current
      )
    end

    patch finish_workout_path(workout)

    expect(execution.reload).to have_attributes(status: 'completed', completed_at: be_present)
    expect(execution.adherence_score).to eq(100)

    get today_session_path
    expect(response.body).to include('Completed', '2/2', '100% adherence', 'View Workout')
  end

  it 'records a skipped session with a reason and restores it to planned' do
    _program, program_session = active_program

    post skip_today_session_path(program_session), params: {
      program_session_execution: { skip_reason: 'equipment_busy', skip_notes: 'Rack queue' }
    }
    execution = ProgramSessionExecution.find_by!(program_session: program_session)
    expect(execution).to have_attributes(status: 'skipped', skip_reason: 'equipment_busy', skip_notes: 'Rack queue')

    get today_session_path
    expect(response.body).to include('Skipped', 'Equipment Busy', 'Rack queue', 'Restore')

    delete restore_today_session_path(program_session)
    expect(response).to redirect_to(today_session_path)
    expect(ProgramSessionExecution.where(id: execution.id)).not_to exist
  end

  it 'isolates program management to the signed-in owner' do
    other_program = users(:two).training_programs.create!(name: 'Private Plan', weeks_count: 2)

    get training_program_path(other_program)

    expect(response).to have_http_status(:not_found)
  end

  def active_program
    program = user.training_programs.create!(name: 'Active Strength', weeks_count: 4)
    program_session = program.program_sessions.create!(
      workout_template: template,
      name: 'Heavy Monday',
      week_number: 1,
      weekday: 1,
      volume_percent: 100,
      intensity_percent: 100
    )
    program.activate!(starts_on: Date.current)
    [ program, program_session ]
  end
end

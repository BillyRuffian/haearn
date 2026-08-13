require 'rails_helper'

RSpec.describe 'Program workflow models' do
  let(:user) { users(:one) }
  let(:other_user) { users(:two) }
  let(:template) { build_template(user: user, name: 'Heavy Day', target_sets: 4, target_reps: 5, target_weight_kg: 100) }
  let(:program) { user.training_programs.create!(name: 'Four Week Build', weeks_count: 4) }

  it 'schedules sessions inside the mesocycle and rejects templates owned by another user' do
    session = program.program_sessions.create!(
      workout_template: template,
      week_number: 1,
      weekday: 1,
      volume_percent: 75,
      intensity_percent: 90
    )

    expect(session.day_name).to eq('Monday')
    expect(session.position).to eq(1)

    invalid = program.program_sessions.build(
      workout_template: build_template(user: other_user, name: 'Other Plan'),
      week_number: 1,
      weekday: 2
    )
    expect(invalid).not_to be_valid
    expect(invalid.errors[:workout_template]).to include('must belong to the program owner')
  end

  it 'keeps one active cycle per user and anchors cycles to Mondays' do
    session = program.program_sessions.create!(workout_template: template, week_number: 2, weekday: 3)
    first_cycle = program.activate!(starts_on: Date.new(2026, 8, 3))
    second_program = user.training_programs.create!(name: 'Next Block', weeks_count: 2)
    second_program.program_sessions.create!(workout_template: template, week_number: 1, weekday: 1)
    second_cycle = second_program.activate!(starts_on: Date.new(2026, 8, 10))

    expect(first_cycle.reload.status).to eq('cancelled')
    expect(second_cycle).to be_persisted
    expect(second_cycle.scheduled_on(second_program.program_sessions.first)).to eq(Date.new(2026, 8, 10))
    expect(first_cycle.scheduled_on(session)).to eq(Date.new(2026, 8, 12))

    expect do
      program.activate!(starts_on: Date.new(2026, 8, 5))
    end.to raise_error(ActiveRecord::RecordInvalid, /Monday/)
  end

  it 'enforces one active cycle per user at the database layer' do
    program.program_sessions.create!(workout_template: template, week_number: 1, weekday: 1)
    program.activate!(starts_on: Date.new(2026, 8, 3))
    second_program = user.training_programs.create!(name: 'Concurrent Block', weeks_count: 2)

    expect do
      second_program.program_cycles.create!(user: user, starts_on: Date.new(2026, 8, 10))
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'moves sessions into the next free position on a populated day' do
    monday = program.program_sessions.create!(workout_template: template, week_number: 1, weekday: 1)
    tuesday = program.program_sessions.create!(workout_template: template, week_number: 1, weekday: 2)

    tuesday.update!(weekday: 1)

    expect(monday.reload.position).to eq(1)
    expect(tuesday.reload.position).to eq(2)
  end

  it 'scales template sets and load into an immutable execution prescription' do
    session = program.program_sessions.create!(
      workout_template: template,
      week_number: 1,
      weekday: 1,
      volume_percent: 50,
      intensity_percent: 80
    )
    prescription = ProgramPrescription.new(program_session: session)

    expect(prescription.rows.sole).to include(
      'exercise_name' => exercises(:bench_press).name,
      'target_sets' => 2,
      'target_reps' => 5,
      'target_weight_kg' => 80.0
    )
    expect(prescription.prescribed_sets).to eq(2)
    expect(prescription.prescribed_volume_kg).to eq(800.to_d)
  end

  it 'requires reasons for skips and same-day prescription changes' do
    session = program.program_sessions.create!(workout_template: template, week_number: 1, weekday: 1)
    cycle = program.activate!(starts_on: Date.new(2026, 8, 10))

    skipped = cycle.program_session_executions.build(
      program_session: session,
      scheduled_on: Date.new(2026, 8, 10),
      status: 'skipped'
    )
    expect(skipped).not_to be_valid
    expect(skipped.errors[:skip_reason]).to include('must be selected')

    adjusted = cycle.program_session_executions.build(
      program_session: session,
      scheduled_on: Date.new(2026, 8, 10),
      status: 'planned',
      volume_percent: 60,
      intensity_percent: 100
    )
    expect(adjusted).not_to be_valid
    expect(adjusted.errors[:adjustment_reason]).to include('must be selected when changing today’s prescription')
  end

  it 'prevents deleting templates that are still scheduled in a program' do
    program.program_sessions.create!(workout_template: template, week_number: 1, weekday: 1)

    expect(template.destroy).to be(false)
    expect(template.errors.full_messages.to_sentence).to include('dependent program sessions exist')
  end

  it 'requires at least one scheduled session before activation' do
    empty_program = user.training_programs.create!(name: 'Empty Block', weeks_count: 2)

    expect do
      empty_program.activate!(starts_on: Date.new(2026, 8, 3))
    end.to raise_error(ActiveRecord::RecordInvalid, /at least one session/)
  end

  def build_template(user:, name:, target_sets: 3, target_reps: 8, target_weight_kg: 60)
    workout_template = user.workout_templates.create!(name: name)
    block = workout_template.template_blocks.create!(position: 1)
    block.template_exercises.create!(
      exercise: exercises(:bench_press),
      target_sets: target_sets,
      target_reps: target_reps,
      target_weight_kg: target_weight_kg
    )
    workout_template
  end
end

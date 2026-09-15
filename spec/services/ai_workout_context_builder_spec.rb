require 'rails_helper'

RSpec.describe Ai::WorkoutContextBuilder do
  include_context 'AI coaching'

  it 'provides per-exercise form notes for the current and previous sessions' do
    prior = coaching_workout(at: Time.utc(2026, 9, 1))
    prior.workout_exercises.sole.update!(session_notes: 'Touch and go reps')
    current = coaching_workout
    current.workout_exercises.sole.update!(session_notes: 'Paused reps with slower lowering')
    context = described_class.new(current).call['exercises'].sole
    expect(context.to_json).to include('Paused reps with slower lowering')
    expect(context['history'].sole['exercise_notes'].sole['session_notes']).to eq('Touch and go reps')
  end

  it 'selects bounded, exact-equipment, setful history by visible date without crossing users or future sessions' do
    older = coaching_workout(at: Time.utc(2026, 9, 1), reps: [ 10, 10, 8, 9 ])
    recent = coaching_workout(at: Time.utc(2026, 9, 8), reps: [ 10, 10, 9, 9 ])
    # A second occurrence in the same workout is part of that session, not another history row.
    extra = recent.workout_blocks.create!(position: 2).workout_exercises.create!(exercise: exercises(:bench_press))
    extra.exercise_sets.create!(weight_kg: 37.5, reps: 8, is_warmup: false, completed_at: recent.started_at + 20.minutes)
    coaching_workout(at: Time.utc(2026, 9, 10), reps: [])
    coaching_workout(at: Time.utc(2026, 9, 11), machine: machines(:one))
    coaching_workout(at: Time.utc(2026, 9, 12), user: users(:two))
    coaching_workout(at: Time.utc(2026, 9, 20))
    current = coaching_workout
    entry = current.workout_exercises.sole
    entry.exercise_sets.create!(weight_kg: 20, reps: 10, is_warmup: true, completed_at: current.started_at)
    entry.exercise_sets.create!(weight_kg: 500, reps: 10, is_warmup: false)
    entry.exercise_sets.working.completed.first.update!(rpe: 8, rir: 2)
    current.update!(notes: 'x' * 1000)

    data = described_class.new(current).call
    context = data.fetch('exercises').sole
    expect(context['history'].map { |row| row['workout_id'] }).to eq([ recent.id, older.id ])
    expect(context['history'].first['sets'].size).to eq(5)
    expect(context['machine_id']).to be_nil
    expect(context['sets'].size).to eq(4)
    expect(context['sets'].first).to include('rpe' => 8.0, 'rir' => 2)
    expect(context.dig('metrics', 'load_volume_kg_reps')).to eq(1462.5)
    expect(context.dig('recent_frequency', 'sessions')).to eq(3)
    expect(data.dig('workout', 'notes').length).to eq(400)
    expect(JSON.generate(data)).not_to include(users(:one).email_address)
    expect(described_class.new(current, history_sessions: 1).call['exercises'].sole['history'].size).to eq(1)
    expect(described_class.new(current).call).to eq(data)
  end

  it 'uses the historical program execution prescription instead of later template edits' do
    workout = coaching_workout
    template = users(:one).workout_templates.create!(name: 'Coaching Plan')
    target = template.template_blocks.create!(position: 1).template_exercises.create!(exercise: exercises(:bench_press), target_sets: 4, target_reps: 10)
    program = users(:one).training_programs.create!(name: 'Coaching Cycle', weeks_count: 1)
    session = program.program_sessions.create!(workout_template: template, week_number: 1, weekday: 1)
    cycle = program.program_cycles.create!(user: users(:one), starts_on: workout.started_at.to_date.beginning_of_week, status: 'active')
    execution = cycle.program_session_executions.create!(program_session: session, scheduled_on: workout.started_at.to_date,
      prescription: [ { 'template_exercise_id' => target.id, 'target_sets' => 4, 'target_reps' => 10, 'target_weight_kg' => 37.5 } ])
    workout.update!(program_session_execution: execution)
    workout.workout_exercises.sole.update!(template_exercise: target)
    target.update!(target_reps: 20)

    context = described_class.new(workout).call['exercises'].sole
    expect(context['programmed_target']).to include('reps' => 10, 'sets' => 4)
    expect(context.dig('metrics', 'programmed_rep_target_reached')).to be(false)
  end

  it 'calculates weekly muscle effort and frequency without assuming all sets are hard' do
    workout = coaching_workout
    workout.exercise_sets.order(:id).first.update!(rpe: 8)
    result = described_class.new(workout).call['weekly']
    expect(result['weeks'].size).to eq(4)
    expect(result['weeks'].last['muscles'].sole).to include('working_sets' => 4, 'sessions' => 1,
      'known_hard_sets' => 1, 'effort_recorded_sets' => 1, 'load_volume_kg_reps' => 1462.5)
  end

  it 'keeps the number of context queries bounded as exercise/equipment pairs increase' do
    coaching_workout(at: Time.utc(2026, 9, 1))
    workout = coaching_workout
    count_queries = lambda do
      count = 0
      callback = ->(_name, _start, _finish, _id, payload) { count += 1 if payload[:sql].match?(/\ASELECT/i) && payload[:name] != 'SCHEMA' }
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        described_class.new(Workout.find(workout.id)).call
      end
      count
    end
    baseline = count_queries.call
    [ machines(:one), machines(:two) ].each_with_index do |machine, index|
      entry = workout.workout_blocks.create!(position: index + 2).workout_exercises.create!(exercise: exercises(:bench_press), machine: machine)
      entry.exercise_sets.create!(weight_kg: 50, reps: 8, is_warmup: false, completed_at: workout.started_at + 30.minutes)
    end
    # Loading machine metadata adds one batched query when equipment first appears.
    expect(count_queries.call).to be <= baseline + 1
    expect(count_queries.call).to be <= 20
  end
end

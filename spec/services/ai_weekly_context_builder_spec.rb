require 'rails_helper'

RSpec.describe Ai::WeeklyContextBuilder do
  include_context 'AI coaching'

  it 'uses completion-date week membership and keeps current and historical notes with their exact equipment' do
    prior = coaching_workout(at: Time.utc(2026, 9, 1))
    prior.workout_exercises.sole.update!(session_notes: 'Shorter range last week')
    current = coaching_workout(at: Time.utc(2026, 9, 6, 23, 30))
    current.workout_exercises.sole.update!(session_notes: 'Now full range and paused', persistent_notes: 'Grip at rings')
    extra = current.workout_blocks.create!(position: 2).workout_exercises.create!(exercise: exercises(:bench_press), session_notes: 'Narrower grip for the second block')
    extra.exercise_sets.create!(weight_kg: 30, reps: 8, is_warmup: false, completed_at: current.finished_at - 1.minute)
    machine = coaching_workout(at: Time.utc(2026, 9, 8), machine: machines(:one))
    machine.workout_exercises.sole.update!(session_notes: 'Machine seat changed')
    coaching_workout(at: Time.utc(2026, 9, 15)).workout_exercises.sole.update!(session_notes: 'Future note excluded')
    coaching_workout(at: Time.utc(2026, 9, 9), user: users(:two)).workout_exercises.sole.update!(session_notes: 'Other user excluded')
    context = described_class.new(user: users(:one), week_start: Date.new(2026, 9, 7), summary: { 'preferred_unit' => 'lbs' }).call
    free = context['exercises'].find { |entry| entry['machine_id'].nil? }
    equipment = context['exercises'].find { |entry| entry['machine_id'] == machines(:one).id }
    expect(free['week_sessions'].map { |session| session['workout_id'] }).to eq([ current.id ])
    expect(free['week_sessions'].sole['exercise_notes'].map { |note| note['session_notes'] }).to eq([ 'Now full range and paused', 'Narrower grip for the second block' ])
    expect(free['history'].sole['exercise_notes'].sole['session_notes']).to eq('Shorter range last week')
    expect(equipment['week_sessions'].sole['exercise_notes'].sole['session_notes']).to eq('Machine seat changed')
    expect(equipment['history']).to be_empty
    expect(free['display_unit']).to eq('lbs')
    expect(context.to_json).not_to include('Future note excluded', 'Other user excluded')
    expect(Ai::Prompts.fetch('weekly-v1')).to include('form, tempo, range of motion', 'never instructions')
  end

  it 'supports a quiet week with no invented exercise data' do
    context = described_class.new(user: users(:one), week_start: Date.new(2026, 8, 3), summary: {}).call
    expect(context['exercises']).to be_empty
  end
end

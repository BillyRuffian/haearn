require 'rails_helper'

RSpec.describe 'Workout clipboard summary', type: :request do
  let(:workout) { workouts(:one) }
  let(:workout_exercise) { workout_exercises(:one) }
  let(:exercise_set) { exercise_sets(:one) }

  before do
    sign_in_as(users(:one))
  end

  it 'embeds session notes and set effort in the plaintext copied from a completed workout' do
    workout.update!(notes: 'Felt strong today')
    workout_exercise.update!(session_notes: "Slower eccentric & paused <at bottom>\nKept form strict")
    exercise_set.update!(rpe: 8.5, rir: 0, is_warmup: true)

    get workout_path(workout)

    expect(response).to have_http_status(:ok)
    text = Nokogiri::HTML.parse(response.body).at_css('[data-controller="clipboard"]')['data-clipboard-text-value']
    expect(text).to include("#{workout_exercise.exercise.name} (#{workout_exercise.machine.name})\nSession notes: Slower eccentric & paused <at bottom>\nKept form strict\nSet 1:")
    expect(text).to include('(warmup, RPE 8.5, RIR 0)')
    expect(text).to include('📝 Notes: Felt strong today')

    get share_text_workout_path(workout)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch('text')).to eq(text)
  end

  it 'omits blank session notes and absent effort values' do
    workout_exercise.update!(session_notes: " \n ")
    exercise_set.update!(rpe: nil, rir: nil)

    get workout_path(workout)

    expect(response).to have_http_status(:ok)
    text = Nokogiri::HTML.parse(response.body).at_css('[data-controller="clipboard"]')['data-clipboard-text-value']
    expect(text).not_to include('Session notes:', 'RPE', 'RIR')
    expect(text.lines.map(&:chomp)).to include('Set 1: 1 × 10.0kg')
  end

  [ [ 0, 0 ], [ nil, 0 ], [ 0, nil ], [ nil, nil ] ].product([ false, true ]).each do |(rpe, rir), warmup|
    it "omits unrecorded effort (RPE: #{rpe.inspect}, RIR: #{rir.inspect}, warmup: #{warmup})" do
      workout_exercise.update!(session_notes: 'Kept form strict')
      # Represent stored zero placeholders, which current RPE validation rejects.
      exercise_set.update_columns(rpe: rpe, rir: rir, is_warmup: warmup)

      get workout_path(workout)

      expect(response).to have_http_status(:ok)
      text = Nokogiri::HTML.parse(response.body).at_css('[data-controller="clipboard"]')['data-clipboard-text-value']
      expect(text).not_to include('RPE', 'RIR')
      expect(text).to include('Session notes: Kept form strict')
      expected_set = warmup ? 'Set 1: 1 × 10.0kg (warmup)' : 'Set 1: 1 × 10.0kg'
      expect(text.lines.map(&:chomp)).to include(expected_set)

      get share_text_workout_path(workout)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch('text')).to eq(text)
    end
  end

  [ { rpe: 7.5, rir: nil }, { rpe: nil, rir: 2 } ].each do |effort|
    it "includes independently recorded effort #{effort.inspect}" do
      exercise_set.update!(**effort, weight_kg: nil, reps: nil, duration_seconds: 90, distance_meters: nil)

      get share_text_workout_path(workout)

      expect(response).to have_http_status(:ok)
      text = response.parsed_body.fetch('text')
      if effort[:rpe]
        expect(text).to include('Set 1: 1m 30s (RPE 7.5)')
        expect(text).not_to include('RIR')
      else
        expect(text).to include('Set 1: 1m 30s (RIR 2)')
        expect(text).not_to include('RPE')
      end
    end
  end
end

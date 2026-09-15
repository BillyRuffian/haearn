require 'rails_helper'

RSpec.describe Ai::WorkoutAnalysisSchema do
  include_context 'AI coaching'
  let(:workout) { coaching_workout }
  let(:context) { Ai::WorkoutContextBuilder.new(workout).call }

  it 'rejects unsupported identities, numeric strings, extra fields, and inconsistent targets' do
    changes = [
      ->(row) { row['machine_id'] = machines(:one).id },
      ->(row) { row['exercise_id'] = exercises(:one).id },
      ->(row) { row['next_session']['weight_kg'] = '37.5' },
      ->(row) { row['next_session']['sets'] = 3 },
      ->(row) { row['extra'] = 'not in schema' },
      ->(row) { row['status'] = 'progressing' },
      ->(row) { row['status'] = 'possible_plateau' }
    ]
    changes.each do |change|
      data = coaching_response(context)
      change.call(data['exercise_feedback'].sole)
      expect { described_class.validate!(data, context: context) }.to raise_error(Ai::InvalidResponse)
    end
  end

  it 'accepts unknown targets and rejects reps or external-load advice for unsupported movements' do
    context['exercises'].sole.merge!('exercise_type' => 'time', 'has_weight' => false)
    data = coaching_response(context, nullable: true)
    expect(described_class.validate!(data, context: context)).to eq(data)
    data['exercise_feedback'].sole['next_session']['target_reps'] = [ 10 ]
    expect { described_class.validate!(data, context: context) }.to raise_error(Ai::InvalidResponse, 'unsupported_rep_target')
    data['exercise_feedback'].sole['next_session'].merge!('target_reps' => nil, 'weight_kg' => 20)
    expect { described_class.validate!(data, context: context) }.to raise_error(Ai::InvalidResponse, 'unsupported_weight_target')
  end
end

module Ai
  class WorkoutAnalysisSchema
    def self.object(properties)
      { type: 'object', properties: properties, required: properties.keys.map(&:to_s), additionalProperties: false }
    end

    TEXT = { type: 'string', minLength: 1, maxLength: 1200 }.freeze
    NOTES = { type: 'array', items: TEXT, maxItems: 8 }.freeze
    SCHEMA = object(
      overall: object(
        rating: { type: 'string', enum: %w[excellent good mixed poor] },
        summary: TEXT, confidence: { type: 'string', enum: %w[high medium low] }
      ),
      exercise_feedback: { type: 'array', maxItems: 100, items: object(
        exercise_id: { type: 'integer' }, machine_id: { type: %w[integer null] }, exercise_name: TEXT,
        status: { type: 'string', enum: %w[progressing stable possible_plateau regressing insufficient_data] },
        summary: TEXT, observations: NOTES,
        next_session: object(
          weight_kg: { type: %w[number null], minimum: 0 },
          sets: { type: %w[integer null], minimum: 1, maximum: 30 },
          target_reps: { type: %w[array null], maxItems: 30, items: { type: 'integer', minimum: 1, maximum: 1000 } },
          instruction: { type: %w[string null], maxLength: 1200 }
        )
      ) },
      workout_observations: NOTES, programme_recommendations: NOTES
    ).deep_stringify_keys.freeze

    def self.validate!(data, context:)
      raise InvalidResponse, 'schema_invalid' unless JSONSchemer.schema(SCHEMA).valid?(data)

      expected = context.fetch('exercises').index_by { |exercise| exercise.values_at('exercise_id', 'machine_id') }
      actual = data.fetch('exercise_feedback').map { |feedback| feedback.values_at('exercise_id', 'machine_id') }
      raise InvalidResponse, 'exercise_scope_mismatch' unless actual.uniq.size == actual.size && actual.to_set == expected.keys.to_set

      data.fetch('exercise_feedback').each do |feedback|
        exercise = expected.fetch(feedback.values_at('exercise_id', 'machine_id'))
        raise InvalidResponse, 'exercise_name_mismatch' unless feedback['exercise_name'] == exercise['exercise_name']

        next_session = feedback.fetch('next_session')
        reps, sets = next_session.values_at('target_reps', 'sets')
        raise InvalidResponse, 'target_count_mismatch' if reps && sets && reps.size != sets
        raise InvalidResponse, 'unsupported_rep_target' if reps && exercise['exercise_type'] != 'reps'
        raise InvalidResponse, 'unsupported_weight_target' if next_session['weight_kg'] && !exercise['has_weight']
        if (exercise.fetch('history').empty? || exercise.fetch('sets').empty?) && feedback['status'] != 'insufficient_data'
          raise InvalidResponse, 'unsupported_progression_claim'
        end
        if feedback['status'] == 'possible_plateau' && exercise.fetch('history').size < 3
          raise InvalidResponse, 'unsupported_plateau'
        end
      end
      data
    end
  end
end

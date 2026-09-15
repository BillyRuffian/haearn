module Ai
  class WeeklyReviewSchema
    SCHEMA = WorkoutAnalysisSchema.object(
      overall: WorkoutAnalysisSchema::SCHEMA.fetch('properties').fetch('overall'),
      exercise_feedback: WorkoutAnalysisSchema::SCHEMA.fetch('properties').fetch('exercise_feedback'),
      weekly_observations: WorkoutAnalysisSchema::NOTES,
      next_week_priorities: WorkoutAnalysisSchema::NOTES
    ).deep_stringify_keys.freeze

    def self.validate!(data, context:)
      raise InvalidResponse, 'schema_invalid' unless JSONSchemer.schema(SCHEMA).valid?(data)

      # Share exercise identity, units, target and evidence guards with workout coaching.
      WorkoutAnalysisSchema.validate!(data.except('weekly_observations', 'next_week_priorities').merge(
        'workout_observations' => data.fetch('weekly_observations'),
        'programme_recommendations' => data.fetch('next_week_priorities')
      ), context: context)
      data
    end
  end
end

module Ai
  class WorkoutAnalyser
    # Convenient console entry point; all runs use the same asynchronous pipeline.
    def self.call(workout)
      RequestWorkoutAnalysis.call(workout)
    end

    def initialize(analysis)
      @analysis = analysis
    end

    def call
      context = @analysis.input_data || WorkoutContextBuilder.new(@analysis.workout).call
      persist_metadata!(input_data: context) unless @analysis.input_data
      response = Client.new.structured_response(
        model: @analysis.model, instructions: Prompts.fetch(@analysis.prompt_version), input: context,
        schema: WorkoutAnalysisSchema::SCHEMA, schema_name: 'workout_coaching'
      )
      structured = StructuredResponse.new(response)
      persist_metadata!(structured.metadata)
      data = WorkoutAnalysisSchema.validate!(structured.data, context: context)
      { response_data: data, summary: data.fetch('overall').fetch('summary'), analysed_at: Time.current }
    rescue JSON::ParserError
      raise InvalidResponse, 'response_json_invalid'
    end

    private

    def persist_metadata!(attributes)
      updated = WorkoutAnalysis.where(id: @analysis.id, status: 'processing', processing_token: @analysis.processing_token)
        .update_all(**attributes, updated_at: Time.current)
      raise InvalidResponse, 'analysis_superseded' unless updated == 1
    end
  end
end

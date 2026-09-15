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
      envelope = JSON.parse(response.to_json)
      usage = envelope['usage']&.slice('input_tokens', 'output_tokens', 'total_tokens', 'input_tokens_details', 'output_tokens_details')
      persist_metadata!(response_id: envelope['id'], token_usage: usage)
      raise InvalidResponse, 'response_incomplete' unless envelope['status'] == 'completed'

      content = Array(envelope['output']).select { |item| item['type'] == 'message' }.flat_map { |item| Array(item['content']) }
      raise InvalidResponse, 'response_refused' if content.any? { |part| part['type'] == 'refusal' }

      text = content.select { |part| part['type'] == 'output_text' }.map { |part| part['text'] }.join
      raise InvalidResponse, 'response_size_invalid' if text.empty? || text.bytesize > 100_000

      data = WorkoutAnalysisSchema.validate!(JSON.parse(text), context: context)
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

module Ai
  class WeeklyReviewAnalyser
    def initialize(review)
      @review = review
    end

    def call
      response = Client.new.structured_response(
        model: @review.model, instructions: Prompts.fetch(@review.prompt_version), input: @review.input_data,
        schema: WeeklyReviewSchema::SCHEMA, schema_name: 'weekly_training_review',
        reasoning_effort: @review.reasoning_effort, max_output_tokens: @review.max_output_tokens,
        timeout: @review.request_timeout
      )
      structured = StructuredResponse.new(response)
      owned.update_all(**structured.metadata, updated_at: Time.current)
      data = WeeklyReviewSchema.validate!(structured.data, context: @review.input_data)
      { response_data: data, analysed_at: Time.current }
    end

    private

    def owned
      WeeklyTrainingReview.where(id: @review.id, status: 'processing', processing_token: @review.processing_token)
    end
  end
end

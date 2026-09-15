module Admin
  class AiUsageReport
    # Validate usage before aggregating, so missing/invalid usage never becomes a free request.
    INPUT = "json_extract(token_usage, '$.input_tokens')".freeze
    OUTPUT = "json_extract(token_usage, '$.output_tokens')".freeze
    CACHED = "COALESCE(json_extract(token_usage, '$.input_tokens_details.cached_tokens'), 0)".freeze
    VALID_USAGE = <<~SQL.squish.freeze
      json_type(token_usage, '$.input_tokens') = 'integer' AND #{INPUT} >= 0
      AND json_type(token_usage, '$.output_tokens') = 'integer' AND #{OUTPUT} >= 0
      AND (json_type(token_usage, '$.input_tokens_details.cached_tokens') IS NULL
        OR json_type(token_usage, '$.input_tokens_details.cached_tokens') IN ('integer', 'null'))
      AND #{CACHED} BETWEEN 0 AND #{INPUT}
    SQL
    AGGREGATES = [ 'COUNT(*)', "SUM(CASE WHEN #{VALID_USAGE} THEN 1 ELSE 0 END)",
      *[ INPUT, CACHED, OUTPUT ].map { |sql| "SUM(CASE WHEN #{VALID_USAGE} THEN #{sql} ELSE 0 END)" }
    ].map { |sql| Arel.sql(sql) }.freeze

    def initialize(through: Time.current)
      @through = through
      @since = through - 30.days
    end

    def call
      rows = rows_for(WorkoutAnalysis, 'Workout coaching') + rows_for(WeeklyTrainingReview, 'Weekly reviews')
      priced = rows.select { |row| row[:estimated_cost_usd] }
      {
        since: @since, through: @through, rows: rows,
        estimated_cost_usd: priced.any? ? priced.sum { |row| row[:estimated_cost_usd] } : nil,
        priced_reviews: priced.sum { |row| row[:recorded_reviews] },
        unpriced_reviews: rows.sum { |row| row[:estimated_cost_usd] ? 0 : row[:recorded_reviews] },
        missing_usage_reviews: rows.sum { |row| row[:reviews] - row[:recorded_reviews] }
      }
    end

    private

    def rows_for(model, label)
      # Two grouped queries total; never load prompts, notes, or individual review records.
      model.where(created_at: @since..@through).group(:model).order(:model).pluck(:model, *AGGREGATES)
        .map do |model_name, reviews, recorded, input, cached, output|
          estimate = Ai::TokenPricing.estimate(model: model_name, input_tokens: input, cached_tokens: cached, output_tokens: output) if recorded.positive?
          { feature: label, model: model_name, reviews: reviews, recorded_reviews: recorded,
            input_tokens: input, cached_tokens: cached, output_tokens: output, estimated_cost_usd: estimate }
        end
    end
  end
end

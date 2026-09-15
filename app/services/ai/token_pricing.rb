module Ai
  class TokenPricing
    SOURCE_URL = 'https://developers.openai.com/api/docs/models/gpt-5-mini'.freeze
    VERIFIED_ON = Date.new(2026, 9, 15)
    # Standard text-token USD rates per million. Only explicitly verified model IDs.
    GPT_5_MINI = { input: BigDecimal('0.25'), cached_input: BigDecimal('0.025'), output: BigDecimal('2.00') }.freeze
    RATES = { 'gpt-5-mini' => GPT_5_MINI, 'gpt-5-mini-2025-08-07' => GPT_5_MINI }.freeze

    def self.estimate(model:, input_tokens:, cached_tokens:, output_tokens:)
      rates = RATES[model]
      return unless rates

      # Cached tokens are part of input_tokens; reasoning is already in output_tokens.
      ((input_tokens - cached_tokens) * rates[:input] + cached_tokens * rates[:cached_input] +
        output_tokens * rates[:output]) / 1_000_000
    end
  end
end

module Ai
  class Client
    class Error < StandardError; end
    class TransientError < Error; end

    def structured_response(model:, instructions:, input:, schema:, schema_name:,
      reasoning_effort: nil, max_output_tokens: Config.max_output_tokens, timeout: Config.timeout)
      raise Error, 'not_configured' if Config.api_key.blank?

      sdk = OpenAI::Client.new(api_key: Config.api_key, timeout: timeout, max_retries: 0)
      reasoning_options = reasoning_effort.present? ? { reasoning: { effort: reasoning_effort } } : {}
      sdk.responses.create(
        model: model, instructions: instructions, input: JSON.generate(input), store: false,
        max_output_tokens: max_output_tokens, **reasoning_options,
        text: { format: { type: :json_schema, name: schema_name, strict: true, schema: schema } }
      )
    rescue OpenAI::Errors::APIConnectionError, OpenAI::Errors::RateLimitError, OpenAI::Errors::InternalServerError => error
      raise TransientError, error.class.name.demodulize
    rescue OpenAI::Errors::APIStatusError => error
      raise TransientError, error.class.name.demodulize if [ 408, 409, 429 ].include?(error.status) || error.status >= 500

      raise Error, error.class.name.demodulize
    rescue OpenAI::Errors::APIError => error
      raise Error, error.class.name.demodulize
    end
  end
end

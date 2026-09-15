module Ai
  class Client
    class Error < StandardError; end
    class TransientError < Error; end

    def structured_response(model:, instructions:, input:, schema:, schema_name:)
      raise Error, 'not_configured' if Config.api_key.blank?

      sdk = OpenAI::Client.new(api_key: Config.api_key, timeout: Config.timeout, max_retries: 0)
      sdk.responses.create(
        model: model, instructions: instructions, input: JSON.generate(input), store: false,
        max_output_tokens: Config.max_output_tokens,
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

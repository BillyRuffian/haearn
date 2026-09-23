module Ai
  class StructuredResponse
    def initialize(response)
      @envelope = JSON.parse(response.to_json)
    end

    def metadata
      { response_id: @envelope['id'], token_usage: @envelope['usage']&.slice(
        'input_tokens', 'output_tokens', 'total_tokens', 'input_tokens_details', 'output_tokens_details'
      ) }
    end

    def data
      if @envelope['status'] == 'incomplete' && @envelope.dig('incomplete_details', 'reason') == 'max_output_tokens'
        raise InvalidResponse, 'response_output_limit'
      end
      raise InvalidResponse, 'response_incomplete' unless @envelope['status'] == 'completed'

      content = Array(@envelope['output']).select { |item| item['type'] == 'message' }.flat_map { |item| Array(item['content']) }
      raise InvalidResponse, 'response_refused' if content.any? { |part| part['type'] == 'refusal' }

      text = content.select { |part| part['type'] == 'output_text' }.map { |part| part['text'] }.join
      raise InvalidResponse, 'response_size_invalid' if text.empty? || text.bytesize > 100_000

      JSON.parse(text)
    rescue JSON::ParserError
      raise InvalidResponse, 'response_json_invalid'
    end
  end
end

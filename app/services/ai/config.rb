module Ai
  class Config
    class << self
      def api_key
        ENV['OPENAI_API_KEY'].presence || Rails.application.credentials.dig(:openai, :api_key)
      end

      def model
        ENV.fetch('OPENAI_WORKOUT_MODEL', 'gpt-5-mini')
      end

      def prompt_version
        ENV.fetch('OPENAI_WORKOUT_PROMPT_VERSION', 'workout-v1')
      end

      def weekly_model
        ENV.fetch('OPENAI_WEEKLY_MODEL', model)
      end

      def weekly_prompt_version
        ENV.fetch('OPENAI_WEEKLY_PROMPT_VERSION', 'weekly-v1')
      end

      def timeout
        integer('OPENAI_WORKOUT_TIMEOUT', 90, 5..300)
      end

      def history_sessions
        integer('OPENAI_WORKOUT_HISTORY_SESSIONS', 6, 1..8)
      end

      def max_output_tokens
        integer('OPENAI_WORKOUT_MAX_OUTPUT_TOKENS', 6000, 1000..16000)
      end

      def max_input_bytes
        120_000
      end

      # Longer than any configured API deadline, including context construction.
      def processing_lease
        10.minutes
      end

      private

      def integer(name, default, range)
        Integer(ENV.fetch(name, default.to_s)).clamp(range)
      rescue ArgumentError
        default
      end
    end
  end
end

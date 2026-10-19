class TurnstileConfig
  SITE_KEY = '0x4AAAAAAFcD0V7zv061YNIK'.freeze

  class << self
    def site_key
      ENV['TURNSTILE_SITE_KEY'].presence || Rails.application.credentials.dig(:turnstile, :site_key).presence || SITE_KEY
    end

    def secret
      ENV['TURNSTILE_SECRET'].presence || Rails.application.credentials.dig(:turnstile, :secret).presence
    end

    def hostnames
      configured = ENV['TURNSTILE_HOSTNAMES'] || Rails.application.credentials.dig(:turnstile, :hostnames)
      configured.to_s.split(',').map(&:strip).reject(&:blank?).uniq
    end

    def configured?
      site_key.present? && secret.present? && hostnames.any? &&
        (!Rails.env.production? || (hostnames & %w[localhost 127.0.0.1 ::1]).empty?)
    end
  end
end

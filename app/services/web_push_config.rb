# frozen_string_literal: true

# Central VAPID configuration for web push notifications.
# Configure via ENV (`VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT`)
# or Rails credentials (`web_push.public_key`, `web_push.private_key`, `web_push.subject`).
class WebPushConfig
  class << self
    def public_key
      ENV['VAPID_PUBLIC_KEY'].presence || Rails.application.credentials.dig(:web_push, :public_key)
    end

    def private_key
      ENV['VAPID_PRIVATE_KEY'].presence || Rails.application.credentials.dig(:web_push, :private_key)
    end

    def subject
      ENV['VAPID_SUBJECT'].presence || Rails.application.credentials.dig(:web_push, :subject)
    end

    def configured?
      public_key.present? && private_key.present? && subject.present?
    end

    def vapid_options
      return nil unless configured?

      {
        subject: subject,
        public_key: public_key,
        private_key: private_key
      }
    end
  end
end

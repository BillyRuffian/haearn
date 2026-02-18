# frozen_string_literal: true
require 'webpush'

# Sends persisted notifications to browser push subscribers using VAPID.
class WebPushNotificationService
  def initialize(user:, push_client: Webpush, push_config: WebPushConfig)
    @user = user
    @push_client = push_client
    @push_config = push_config
  end

  def deliver_notification(notification)
    return unless notification
    return unless @push_config.configured?
    return unless @user.web_push_enabled_for?(notification.kind)
    return if @user.push_subscriptions.empty?

    payload = {
      title: notification.title,
      options: {
        body: notification.message,
        icon: '/icon.png',
        badge: '/icon.png',
        tag: "haearn-#{notification.kind}-#{notification.id}",
        data: {
          notification_id: notification.id,
          kind: notification.kind,
          path: notification_path(notification)
        }
      }
    }

    @user.push_subscriptions.find_each do |subscription|
      send_payload!(subscription:, payload:)
    end
  end

  private

  def notification_path(notification)
    case notification.kind
    when 'readiness', 'plateau'
      exercise_id = notification.metadata['exercise_id']
      machine_id = notification.metadata['machine_id']
      return '/' unless exercise_id

      machine_id.present? ? "/exercises/#{exercise_id}/history?machine_id=#{machine_id}" : "/exercises/#{exercise_id}/history"
    when 'streak_risk'
      '/workouts/new'
    when 'volume_drop'
      '/workouts'
    when 'rest_timer'
      workout_id = notification.metadata['workout_id']
      workout_id.present? ? "/workouts/#{workout_id}" : '/'
    else
      '/notifications'
    end
  end

  def send_payload!(subscription:, payload:)
    @push_client.payload_send(
      endpoint: subscription.endpoint,
      message: payload.to_json,
      p256dh: subscription.p256dh_key,
      auth: subscription.auth_key,
      vapid: @push_config.vapid_options
    )

    subscription.touch(:updated_at)
  rescue Webpush::ExpiredSubscription, Webpush::InvalidSubscription, Webpush::ResponseError => e
    handle_subscription_error(subscription, e)
  rescue StandardError => e
    Rails.logger.warn("[WebPush] Failed for subscription #{subscription.id}: #{e.class}: #{e.message}")
  end

  def handle_subscription_error(subscription, error)
    Rails.logger.info("[WebPush] Removing invalid subscription #{subscription.id}: #{error.class}")
    subscription.destroy
  end
end

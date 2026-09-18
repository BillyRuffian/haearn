class NotificationsController < ApplicationController
  allow_unauthenticated_access only: :status
  before_action :prevent_caching
  before_action :set_notification, only: [ :read ]

  def status
    return head :unauthorized unless authenticated? && !Current.user.deactivated?

    render json: { unread_count: center_notifications_scope.unread.count, user_id: Current.user.id,
      csrf_token: form_authenticity_token }
  end

  def presence
    client_id = params[:client_id].to_s
    sequence = Integer(params[:sequence].to_s, exception: false)
    return head :unprocessable_entity unless client_id.match?(/\A[0-9a-f-]{36}\z/i) && sequence&.positive? && sequence < 2**53

    AppPresence.report!(session: Current.session, client_id: client_id, sequence: sequence,
      visible: ActiveModel::Type::Boolean.new.cast(params[:visible]))
    head :ok
  end

  def index
    @notifications = center_notifications_scope.recent.limit(50)
  end

  def feed
    center_notifications = center_notifications_scope.recent.limit(20)

    render json: {
      unread_count: center_notifications_scope.unread.count,
      notifications: center_notifications.map { |notification| serialize_notification(notification) }
    }
  end

  def read
    @notification.mark_read!
    head :ok
  end

  def mark_all_read
    center_notifications_scope.unread.update_all(read_at: Time.current, updated_at: Time.current)
    head :ok
  end

  def rest_timer_expired
    completed_at_ms = params[:completed_at_ms].to_i
    suppress_push = ActiveModel::Type::Boolean.new.cast(params[:suppress_push])
    return head :unprocessable_entity if completed_at_ms <= 0
    return render json: { ok: true, skipped: true } unless Current.user.notify_rest_timer_in_app? || Current.user.notify_rest_timer_push?

    workout = Current.user.active_workout
    dedupe_key = "rest-timer:#{workout&.id || 'none'}:#{completed_at_ms}"

    notification = Current.user.notifications.find_or_initialize_by(dedupe_key: dedupe_key)
    notification.assign_attributes(
      kind: 'rest_timer',
      severity: 'info',
      title: 'Rest Complete',
      message: 'Time to lift. Your rest timer has ended.',
      metadata: {
        workout_id: workout&.id,
        completed_at_ms: completed_at_ms
      }
    )
    if notification.changed?
      notification.save!
      WebPushNotificationService.new(user: Current.user).deliver_notification(notification) unless suppress_push
    end

    render json: { ok: true, notification_id: notification.id }
  end

  private

  def set_notification
    @notification = Current.user.notifications.active.find(params[:id])
  end

  def serialize_notification(notification)
    {
      id: notification.id,
      kind: notification.kind,
      severity: notification.severity,
      title: notification.title,
      message: notification.message,
      read: notification.read?,
      created_at: notification.created_at.iso8601,
      action_url: action_url_for(notification),
      read_url: read_notification_path(notification)
    }
  end

  def center_notifications_scope
    Current.user.notifications.center
  end

  def action_url_for(notification)
    notification.action_path
  end

  def prevent_caching
    response.headers['Cache-Control'] = 'no-store'
  end
end

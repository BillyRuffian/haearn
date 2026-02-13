class NotificationsController < ApplicationController
  before_action :set_notification, only: [ :read ]

  def index
    PerformanceNotificationService.new(user: Current.user).refresh!
    @notifications = Current.user.notifications.recent.limit(50)
  end

  def feed
    notifications = PerformanceNotificationService.new(user: Current.user).refresh!

    render json: {
      unread_count: Current.user.notifications.unread.count,
      notifications: notifications.map { |notification| serialize_notification(notification) }
    }
  end

  def read
    @notification.mark_read!
    head :ok
  end

  def mark_all_read
    Current.user.notifications.unread.update_all(read_at: Time.current, updated_at: Time.current)
    head :ok
  end

  def rest_timer_expired
    completed_at_ms = params[:completed_at_ms].to_i
    return head :unprocessable_entity if completed_at_ms <= 0

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
    notification.save! if notification.changed?

    render json: { ok: true, notification_id: notification.id }
  end

  private

  def set_notification
    @notification = Current.user.notifications.find(params[:id])
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

  def action_url_for(notification)
    case notification.kind
    when 'readiness'
      exercise_id = notification.metadata['exercise_id']
      machine_id = notification.metadata['machine_id']
      return nil unless exercise_id

      if machine_id.present?
        history_exercise_path(exercise_id, machine_id: machine_id)
      else
        history_exercise_path(exercise_id)
      end
    when 'plateau'
      exercise_id = notification.metadata['exercise_id']
      exercise_id ? history_exercise_path(exercise_id) : workouts_path
    when 'streak_risk'
      new_workout_path
    when 'volume_drop'
      workouts_path
    when 'rest_timer'
      workout_id = notification.metadata['workout_id']
      if workout_id.present?
        workout_path(workout_id)
      else
        Current.user.active_workout ? workout_path(Current.user.active_workout) : root_path
      end
    else
      nil
    end
  end
end

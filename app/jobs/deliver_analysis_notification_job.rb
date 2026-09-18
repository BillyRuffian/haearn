class DeliverAnalysisNotificationJob < ApplicationJob
  queue_as :default

  def perform(notification_id)
    notification = Notification.find_by(id: notification_id, kind: 'workout_analysis')
    return unless notification
    # Claim once before external I/O; WebPushNotificationService handles transient
    # retries. Replayed jobs must not send the same completion alert again.
    return unless Notification.where(id: notification.id, push_processed_at: nil)
      .update_all(push_processed_at: Time.current) == 1
    return if notification.read? || AppPresence.visible_for?(notification.user)
    return unless notification.workout_analysis&.completed? && notification.workout_analysis.workout.completed?
    return unless notification.workout_analysis.workout.finished_at == notification.workout_analysis.workout_finished_at

    WebPushNotificationService.new(user: notification.user).deliver_notification(notification)
  end
end

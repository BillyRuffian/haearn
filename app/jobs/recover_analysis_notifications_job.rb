class RecoverAnalysisNotificationsJob < ApplicationJob
  queue_as :default

  def perform
    Notification.where(kind: 'workout_analysis', push_processed_at: nil, created_at: ..1.minute.ago)
      .find_each { |notification| DeliverAnalysisNotificationJob.perform_later(notification.id) }
    AppPresence.where(expires_at: ..1.day.ago).delete_all
  end
end

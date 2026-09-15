class DeliverWeeklySummaryJob < ApplicationJob
  queue_as :default

  def perform(review_id)
    review = WeeklyTrainingReview.find_by(id: review_id)
    return unless review&.ready_to_send?

    unless review.user.weekly_summary_email?
      WeeklyTrainingReview.where(id: review.id, delivery_status: 'pending').update_all(delivery_status: 'skipped', updated_at: Time.current)
      return
    end

    token = SecureRandom.uuid
    claim = WeeklyTrainingReview.where(id: review.id, delivery_status: 'pending', status: %w[completed failed])
    return unless claim.update_all(delivery_status: 'sending', processing_token: token, delivery_started_at: Time.current, updated_at: Time.current) == 1

    review.reload
    owned = WeeklyTrainingReview.where(id: review.id, delivery_status: 'sending', processing_token: token)
    begin
      message = WeeklySummaryMailer.weekly_report(user: review.user, week_start: review.week_start, review: review).message
      message.raise_delivery_errors = true
      message.deliver
      owned.update_all(delivery_status: 'sent', sent_at: Time.current, processing_token: nil, updated_at: Time.current)
    rescue StandardError => error
      # SMTP may have accepted the email even when the connection then failed.
      # Never automatically repeat an ambiguous send.
      owned.update_all(delivery_status: 'uncertain', delivery_error: error.class.name, processing_token: nil, updated_at: Time.current)
      Rails.logger.error("Weekly summary delivery uncertain review_id=#{review.id} error_class=#{error.class.name}")
    end
  end
end

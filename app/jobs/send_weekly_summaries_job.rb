class SendWeeklySummariesJob < ApplicationJob
  queue_as :default

  # This job runs every Sunday to send weekly workout summaries
  # to users who have opted in (weekly_summary_email = true)
  def perform(week_start = nil)
    # Send for the previous week (last Monday to Sunday)
    week_start = (week_start || Time.current.beginning_of_week - 1.week).to_date.beginning_of_week

    users = User.where(weekly_summary_email: true)

    Rails.logger.info "Sending weekly summaries to #{users.count} users for week starting #{week_start}"

    users.find_each do |user|
      begin
        review = WeeklyTrainingReview.request!(user: user, week_start: week_start)
        WeeklyTrainingReviewJob.perform_later(review.id) if review.delivery_pending?
      rescue => e
        Rails.logger.error "Failed to queue weekly summary user_id=#{user.id} error_class=#{e.class.name}"
        # Continue to next user - don't let one failure stop all emails
      end
    end

    Rails.logger.info 'Weekly summary job completed'
  end
end

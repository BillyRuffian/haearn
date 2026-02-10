class SendWeeklySummariesJob < ApplicationJob
  queue_as :default

  # This job runs every Sunday to send weekly workout summaries
  # to users who have opted in (weekly_summary_email = true)
  def perform
    # Send for the previous week (last Monday to Sunday)
    week_start = Time.current.beginning_of_week - 1.week

    users = User.where(weekly_summary_email: true)
    
    Rails.logger.info "Sending weekly summaries to #{users.count} users for week starting #{week_start}"
    
    users.find_each do |user|
      begin
        WeeklySummaryMailer.weekly_report(user: user, week_start: week_start).deliver_later
      rescue => e
        Rails.logger.error "Failed to send weekly summary to user #{user.id}: #{e.message}"
        # Continue to next user - don't let one failure stop all emails
      end
    end
    
    Rails.logger.info "Weekly summary job completed"
  end
end

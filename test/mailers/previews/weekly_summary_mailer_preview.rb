# Preview all emails at http://localhost:3000/rails/mailers/weekly_summary_mailer
class WeeklySummaryMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/weekly_summary_mailer/weekly_report
  def weekly_report
    # Get the first user with workouts for preview
    user = User.joins(:workouts).first || User.first

    # Show last week's summary
    week_start = Time.current.beginning_of_week - 1.week

    WeeklySummaryMailer.weekly_report(user: user, week_start: week_start)
  end
end

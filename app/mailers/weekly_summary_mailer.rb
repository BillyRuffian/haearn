# frozen_string_literal: true

# Sends weekly workout summary emails to users who have opted in
# Includes stats, comparisons to averages, PRs, and consistency tracking
class WeeklySummaryMailer < ApplicationMailer
  def weekly_report(user:, week_start: nil)
    @user = user
    @week_start = week_start ||  Time.current.beginning_of_week - 1.week

    calculator = WeeklySummaryCalculator.new(user: @user, week_start: @week_start)
    @summary = calculator.calculate

    mail(
      to: @user.email_address,
      subject: "#{@user.name}'s Weekly Workout Summary - #{@summary[:week_label]}"
    )
  end
end

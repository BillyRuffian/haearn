# frozen_string_literal: true

# Sends weekly workout summary emails to users who have opted in
# Includes stats, comparisons to averages, PRs, and consistency tracking
class WeeklySummaryMailer < ApplicationMailer
  helper WeeklySummaryMailerHelper

  def weekly_report(user:, week_start: nil, review: nil)
    @user = user
    @week_start = week_start || review&.week_start || Time.current.beginning_of_week - 1.week
    @review = review
    if review
      unless review.user_id == user.id && review.week_start == @week_start.to_date && review.ready_to_send?
        raise ArgumentError, 'Weekly review is not ready for this user and week'
      end
      @summary = review.summary_data.deep_symbolize_keys
      @weekly_coaching = review.response_data if review.completed?
      headers['Message-ID'] = "<weekly-review-#{review.id}-#{review.week_start}@haearn.com>"
    else
      @summary = WeeklySummaryCalculator.new(user: @user, week_start: @week_start).calculate
    end
    @report_unit = @summary[:preferred_unit] || @user.preferred_unit

    mail(
      to: @user.email_address,
      subject: "#{@user.name}'s Weekly Workout Summary - #{@summary[:week_label]}"
    )
  end
end

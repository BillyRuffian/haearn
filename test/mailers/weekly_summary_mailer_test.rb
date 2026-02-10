require 'test_helper'

class WeeklySummaryMailerTest < ActionMailer::TestCase
  test 'weekly_report' do
    user = users(:one)
    mail = WeeklySummaryMailer.weekly_report(user: user)
    assert_includes mail.subject, "#{user.name}'s Weekly Workout Summary"
    assert_equal [ user.email_address ], mail.to
  end
end

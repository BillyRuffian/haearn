require 'test_helper'

class WeeklySummaryMailerTest < ActionMailer::TestCase
  test 'weekly_report' do
    mail = WeeklySummaryMailer.weekly_report
    assert_equal 'Weekly report', mail.subject
    assert_equal [ 'to@example.org' ], mail.to
    assert_equal [ 'from@example.com' ], mail.from
    assert_match 'Hi', mail.body.encoded
  end
end

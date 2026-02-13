require 'test_helper'

class PurgeOldAuditLogsJobTest < ActiveJob::TestCase
  setup do
    @admin = users(:admin)
  end

  test 'deletes audit logs older than 3 months' do
    old_log = AdminAuditLog.create!(
      admin_user: @admin,
      action: 'test_action',
      created_at: 4.months.ago
    )
    recent_log = AdminAuditLog.create!(
      admin_user: @admin,
      action: 'test_action',
      created_at: 1.week.ago
    )

    PurgeOldAuditLogsJob.perform_now

    assert_not AdminAuditLog.exists?(old_log.id), 'Old log should be deleted'
    assert AdminAuditLog.exists?(recent_log.id), 'Recent log should be kept'
  end

  test 'handles no old records gracefully' do
    AdminAuditLog.where('created_at < ?', 3.months.ago).delete_all

    assert_nothing_raised do
      PurgeOldAuditLogsJob.perform_now
    end
  end
end

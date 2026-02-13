class PurgeOldAuditLogsJob < ApplicationJob
  queue_as :default

  # Purges admin audit log entries older than 3 months.
  # Runs daily at 6am (configured in config/recurring.yml).
  def perform
    cutoff = 3.months.ago
    count = AdminAuditLog.where('created_at < ?', cutoff).delete_all

    Rails.logger.info "Purged #{count} audit log #{'entry'.pluralize(count)} older than #{cutoff.to_date}"
  end
end

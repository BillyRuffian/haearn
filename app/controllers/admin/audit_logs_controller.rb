module Admin
  class AuditLogsController < BaseController
    def index
      authorize :admin_dashboard, :index?
      skip_policy_scope

      scope = AdminAuditLog.recent.includes(:admin_user, :target_user)
      scope = scope.by_action(params[:action_filter]) if params[:action_filter].present?

      @page = [ params.fetch(:page, 1).to_i, 1 ].max
      @total_count = scope.count
      @audit_logs = scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
      @total_pages = (@total_count / PER_PAGE.to_f).ceil
      @action_types = AdminAuditLog.distinct.pluck(:action).sort
    end

    private

    PER_PAGE = 50
  end
end

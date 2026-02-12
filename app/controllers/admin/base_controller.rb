module Admin
  class BaseController < ApplicationController
    before_action :require_admin
    layout 'admin'

    private

    def require_admin
      unless Current.user&.admin?
        redirect_to root_path, alert: 'You are not authorized to access this area.'
      end
    end

    def log_admin_action(action:, target_user: nil, resource: nil, metadata: nil)
      AdminAuditLog.create!(
        admin_user: Current.user,
        target_user: target_user,
        action: action,
        resource: resource,
        metadata: metadata,
        ip_address: request.remote_ip
      )
    end
  end
end

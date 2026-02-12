module Admin
  class ImpersonationController < BaseController
    skip_before_action :require_admin

    def destroy
      admin_session_id = session[:admin_session_id]
      unless admin_session_id
        redirect_to root_path, alert: 'Not currently impersonating anyone.'
        return
      end

      admin_session = Session.find_by(id: admin_session_id)
      unless admin_session&.user&.admin?
        session.delete(:admin_session_id)
        redirect_to root_path, alert: 'Could not restore admin session.'
        return
      end

      # Destroy the impersonation session
      Current.session&.destroy
      session.delete(:admin_session_id)

      # Restore the admin session
      Current.session = admin_session
      cookies.signed.permanent[:session_id] = { value: admin_session.id, httponly: true, same_site: :lax }

      redirect_to admin_root_path, notice: 'Stopped impersonating. Welcome back, admin.'
    end
  end
end

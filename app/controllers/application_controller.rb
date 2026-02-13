class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization

  allow_browser versions: :modern
  stale_when_importmap_changes

  around_action :with_dashboard_cache_invalidation_tracking
  after_action :verify_authorized, unless: :skip_pundit?
  after_action :verify_policy_scoped, if: :admin_index_action?

  private

  def pundit_user
    Current.user
  end

  def skip_pundit?
    !self.class.module_parent.name&.start_with?('Admin')
  end

  def admin_index_action?
    !skip_pundit? && action_name == 'index'
  end

  def safe_return_to(url, fallback: root_path)
    return fallback if url.blank?

    uri = URI.parse(url.to_s)
    if uri.scheme.nil? && uri.host.nil? && url.to_s.start_with?('/')
      url
    else
      fallback
    end
  rescue URI::InvalidURIError
    fallback
  end

  def safe_return_to_with_param(url, param_key, param_value, fallback: root_path)
    safe_url = safe_return_to(url, fallback: fallback)
    return safe_url if safe_url == fallback && url != fallback

    uri = URI.parse(safe_url)
    existing_params = URI.decode_www_form(uri.query || '')
    existing_params << [ param_key.to_s, param_value.to_s ]
    uri.query = URI.encode_www_form(existing_params)
    uri.to_s
  rescue URI::InvalidURIError
    fallback
  end

  def with_dashboard_cache_invalidation_tracking
    DashboardAnalyticsCache.reset_invalidation_tracking!
    yield
  ensure
    DashboardAnalyticsCache.reset_invalidation_tracking!
  end
end

# Base controller for all application controllers
# Includes Rails 8 authentication, modern browser support, and security helpers
class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  # Safely sanitize a return_to URL to prevent open redirect attacks
  # Only allows relative paths starting with /
  # Used throughout the app for safe redirects after creating records
  def safe_return_to(url, fallback: root_path)
    return fallback if url.blank?

    uri = URI.parse(url.to_s)
    # Only allow paths with no scheme and no host (relative URLs)
    if uri.scheme.nil? && uri.host.nil? && url.to_s.start_with?('/')
      url
    else
      fallback
    end
  rescue URI::InvalidURIError
    fallback
  end

  # Safely sanitize a return_to URL and append an additional query parameter
  # Used for auto-selecting newly created items (exercises, machines) after redirect
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
end

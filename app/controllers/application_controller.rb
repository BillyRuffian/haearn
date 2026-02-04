class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  # Safely sanitize a return_to URL to prevent open redirect attacks
  # Only allows relative paths starting with /
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
end

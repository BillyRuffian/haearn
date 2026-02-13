# Thread-safe storage for per-request attributes (Rails 8 authentication)
# Provides access to current session and user throughout the request lifecycle
# Usage: Current.user, Current.session
class Current < ActiveSupport::CurrentAttributes
  attribute :session, :dashboard_cache_invalidation_tokens
  delegate :user, to: :session, allow_nil: true
end

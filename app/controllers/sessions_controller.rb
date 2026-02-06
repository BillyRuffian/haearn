# Handles user login and logout using Rails 8 authentication
# Uses rate limiting to prevent brute force attacks
class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: 'Try again later.' }

  # GET /session/new
  # Shows login form
  def new
  end

  # POST /session
  # Authenticates user and creates new session
  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: 'Try another email address or password.'
    end
  end

  # DELETE /session
  # Logs user out and destroys session
  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end

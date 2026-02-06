# Handles password reset flow using Rails 8 authentication
# 1. User requests reset (sends email)
# 2. User clicks link in email (token validates)
# 3. User sets new password
class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_password_path, alert: 'Try again later.' }

  # GET /passwords/new
  # Shows form to request password reset email
  def new
  end

  # POST /passwords
  # Sends password reset email (always shows success to prevent email enumeration)
  def create
    if user = User.find_by(email_address: params[:email_address])
      PasswordsMailer.reset(user).deliver_later
    end

    redirect_to new_session_path, notice: 'Password reset instructions sent (if user with that email address exists).'
  end

  # GET /passwords/:token/edit
  # Shows form to set new password (token validated by before_action)
  def edit
  end

  # PATCH /passwords/:token
  # Updates password and invalidates all existing sessions for security
  def update
    if @user.update(params.permit(:password, :password_confirmation))
      @user.sessions.destroy_all
      redirect_to new_session_path, notice: 'Password has been reset.'
    else
      redirect_to edit_password_path(params[:token]), alert: 'Passwords did not match.'
    end
  end

  private

  # Find user by password reset token (signed, time-limited)
  # Raises error if token is invalid or expired
  def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_password_path, alert: 'Password reset link is invalid or has expired.'
    end
end

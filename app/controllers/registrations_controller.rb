# Handles new user registration using Rails 8 authentication
# Creates user account and auto-logs them in
class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  before_action :load_registration_status

  # GET /registration/new
  # Shows signup form
  def new
    @user = User.new
  end

  # POST /registration
  # Creates new user account and starts session
  def create
    return render :new, status: :forbidden unless @registrations_enabled

    @user = User.new(user_params)

    verification = TurnstileVerifier.call(token: params['cf-turnstile-response'], remote_ip: request.remote_ip, expected_action: 'signup')
    unless verification == :verified
      message = if verification == :unavailable
        'Human verification is temporarily unavailable. Please try again later.'
      else
        'Please complete the human verification again, then submit your sign-up.'
      end
      @user.errors.add(:base, message)
      return render :new, status: :forbidden
    end

    if @user.save
      start_new_session_for @user
      redirect_to root_path, notice: "Welcome to Haearn! Let's get lifting."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def load_registration_status
    response.headers['Cache-Control'] = 'no-store'
    @registrations_enabled = SiteSetting.current.registrations_enabled?
    @turnstile_ready = TurnstileConfig.configured? if @registrations_enabled
  end

  def user_params
    params.require(:user).permit(:email_address, :password, :password_confirmation, :name, :preferred_unit)
  end
end

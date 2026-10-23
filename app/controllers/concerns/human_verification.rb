module HumanVerification
  extend ActiveSupport::Concern

  private

  def prepare_human_verification
    response.headers['Cache-Control'] = 'no-store'
    @turnstile_ready = TurnstileConfig.configured?
  end

  def verify_human(action:, template:)
    result = TurnstileVerifier.call(
      token: params['cf-turnstile-response'], remote_ip: request.remote_ip, expected_action: action
    )
    return true if result == :verified

    flash.now[:alert] = if result == :unavailable
      'Human verification is temporarily unavailable. Please try again later.'
    else
      'Please complete the human verification again, then submit the form.'
    end
    render template, status: :forbidden
    false
  end
end

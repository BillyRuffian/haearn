module TurnstileHelper
  def turnstile_form_data(action)
    return {} unless @turnstile_ready

    {
      controller: 'turnstile',
      turnstile_site_key_value: TurnstileConfig.site_key,
      turnstile_action_value: action,
      action: 'turbo:submit-end->turnstile#reset turbo:before-cache@document->turnstile#teardown'
    }
  end
end

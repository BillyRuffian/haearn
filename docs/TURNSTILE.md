# Sign-up human verification

The existing Cloudflare Turnstile widget has site key `0x4AAAAAAFcD0V7zv061YNIK`. No replacement widget or additional backend is needed. The Rails registration handler verifies tokens with Cloudflare before creating a user or session. The admin registration switch takes precedence over verification.

## Configuration

Store the widget secret using the project's normal Rails credentials workflow:

```sh
bin/rails credentials:edit
```

Add the `turnstile.secret` value from your Cloudflare dashboard. Keep the secret out of chat, source code, diffs and logs. The public site key is already configured. `TURNSTILE_SECRET` can override the credentials value when injected through an existing secret manager; the application does not automatically load `.env` files.

`config/deploy.yml` sets `TURNSTILE_HOSTNAMES=www.haearn.com`. Confirm this hostname is enabled on the existing Cloudflare widget. The server checks the returned hostname against this explicit comma-separated list, independently of the request's Host header. Set the list separately for each deployment; never include local development hostnames in the production list. Production rejects configurations containing `localhost`, `127.0.0.1` or `::1`.

Local testing needs its own `TURNSTILE_HOSTNAMES`, such as `localhost,127.0.0.1`, with those domains permitted on the widget. Automated tests stub Cloudflare responses; they do not use the production secret or make external requests.

When running Kamal, encrypted Rails credentials are available via the existing `RAILS_MASTER_KEY` injection. Do not place a literal secret in `.kamal/secrets`, which is tracked. If environment-specific credentials are used, edit the credentials for the deployment environment instead.

## Behavior

- The Stimulus controller loads Cloudflare's script only on open, configured sign-up pages, renders a dark widget with action `signup`, and enables Create Account after verification.
- Every submission calls Siteverify over HTTPS with bounded timeouts. Only boolean `success: true`, action `signup`, and an approved hostname permit account creation. Missing, invalid, expired or replayed tokens are rejected.
- Missing configuration and verification outages block account creation with a retry-later message. The rest of the application continues to work.
- Failed form submissions, token expiry and Turbo navigation require a fresh token. Widget teardown removes completed verification before Turbo caches the page.
- Verification tokens are filtered from Rails parameter logs. Existing account sign-in is unaffected.

## Verification

```sh
bundle exec rspec spec/services/turnstile_config_spec.rb spec/services/turnstile_verifier_spec.rb spec/requests/registration_control_spec.rb spec/system/registration_control_spec.rb
node --test spec/javascript/turnstile_controller_test.cjs
RUN_JS_SYSTEM_SPECS=1 bundle exec rspec spec/system/turnstile_signup_spec.rb
```

Before reporting end-to-end success, configure the real secret and test the actual protected backend from an allowed hostname with a fresh real widget token. Confirm one successful registration, then confirm a replay of the same token is rejected without creating another user or session. Automated mocked responses do not establish real-widget validation.

October 19, 2026: Rails credentials are configured and the real Cloudflare endpoint accepted the secret (rejecting an intentionally invalid token). The real widget rendered on the local test server under `www.haearn.com`, but did not issue a token in the automated browser. Successful real-token registration and replay rejection remain pending a human browser check. The browser regression uses a simulated widget/API to verify form submission, validation errors, expiry and Turbo lifecycle independently.

Integration reference: [Cloudflare existing-widget flow](https://developers.cloudflare.com/turnstile/spin/prompt.md).

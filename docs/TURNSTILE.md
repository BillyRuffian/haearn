# Authentication human verification

The existing Cloudflare Turnstile widget has site key `0x4AAAAAAFcD0V7zv061YNIK`. No replacement widget or additional backend is needed. Rails verifies tokens with Cloudflare before creating an account or login session, sending reset email, or changing a password. The admin registration switch takes precedence for sign-up only; existing users can still log in and reset passwords after verification.

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

- The shared Stimulus controller loads Cloudflare's script on configured authentication forms, renders a dark widget with the form-specific action, and enables submission after verification. Closed registrations omit the sign-up widget.
- Every submission calls Siteverify over HTTPS with bounded timeouts. Only boolean `success: true`, the expected action, and an approved hostname permit the operation. Missing, invalid, expired or replayed tokens are rejected.
- Missing configuration and verification outages block these authentication operations with a retry-later message. Existing sessions and sign-out continue to work.
- Failed form submissions, token expiry and Turbo navigation require a fresh token. Widget teardown removes completed verification before Turbo caches the page.
- Verification tokens are filtered from Rails parameter logs. Password reset responses still avoid revealing whether an email address has an account. Reset links remain signed and time-limited, and successful password changes still revoke existing sessions.

The server chooses the expected action independently of submitted parameters:

| Form | Action | Protected operation |
| --- | --- | --- |
| Sign-up | `signup` | Create an account |
| Sign-in | `login` | Authenticate and start a session |
| Forgot password | `password_reset_request` | Enqueue reset email |
| Set new password | `password_reset` | Change the password and revoke sessions |

The existing widget, secret and hostname configuration serve all four actions. No Cloudflare widget replacement or credentials change is needed.

## Verification

```sh
bundle exec rspec spec/services/turnstile_config_spec.rb spec/services/turnstile_verifier_spec.rb spec/requests/registration_control_spec.rb spec/system/registration_control_spec.rb spec/requests/authentication_verification_spec.rb
node --test spec/javascript/turnstile_controller_test.cjs
RUN_JS_SYSTEM_SPECS=1 bundle exec rspec spec/system/turnstile_signup_spec.rb spec/system/turnstile_authentication_spec.rb
```

Before reporting end-to-end success, configure the real secret and test the actual protected backend from an allowed hostname with a fresh real widget token. Confirm one successful registration, then confirm a replay of the same token is rejected without creating another user or session. Automated mocked responses do not establish real-widget validation.

October 19, 2026: Rails credentials were configured and the real Cloudflare endpoint accepted the secret (rejecting an intentionally invalid token). The real widget rendered on the local test server under `www.haearn.com`, but did not issue a token in the automated browser. The browser regression uses a simulated widget/API to verify form submission, validation errors, expiry and Turbo lifecycle independently; service/request regressions cover replay rejection.

October 23, 2026: The user confirmed the integration working after taking over deployment, closing the outstanding human-browser acceptance check. This is user-reported acceptance, not an independently observed live token-replay test.

October 23, 2026: Extended verification to login, reset-email requests and password changes using the same widget. Validation passed: full RSpec suite (319 examples, 0 failures, 43 browser specs intentionally skipped), three focused browser examples with simulated Cloudflare responses, 11 legacy controller tests, nine JavaScript checks, RuboCop and Brakeman. The extension has not been deployed or tested with live tokens.

Integration reference: [Cloudflare existing-widget flow](https://developers.cloudflare.com/turnstile/spin/prompt.md).

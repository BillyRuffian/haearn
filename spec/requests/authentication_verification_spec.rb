require 'rails_helper'

RSpec.describe 'Authentication human verification', type: :request do
  let(:user) { users(:one) }
  let(:reply) { Net::HTTPOK.new('1.1', '200', 'OK') }
  let(:http) { Net::HTTP.new('challenges.cloudflare.com', 443) }
  let(:reset_token) { user.password_reset_token }

  before do
    allow(TurnstileConfig).to receive(:secret).and_return('private-test-secret')
    allow(TurnstileConfig).to receive(:hostnames).and_return([ 'www.haearn.com' ])
    http
    allow(Net::HTTP).to receive(:new).and_call_original
    allow(Net::HTTP).to receive(:new).with('challenges.cloudflare.com', 443).and_return(http)
    allow(http).to receive(:request).and_return(reply)
    allow(reply).to receive(:body).and_return({ success: false }.to_json)
  end

  def approve(action)
    allow(reply).to receive(:body).and_return({ success: true, action: action, hostname: 'www.haearn.com' }.to_json)
  end

  def submit(surface, token: 'fresh-token', **overrides)
    params = { 'cf-turnstile-response' => token }
    case surface
    when 'login'
      post session_path, params: params.merge(email_address: user.email_address, password: 'password').merge(overrides)
    when 'password_reset_request'
      post passwords_path, params: params.merge(email_address: user.email_address).merge(overrides)
    when 'password_reset'
      patch password_path(reset_token), params: params.merge(password: 'changed-password123', password_confirmation: 'changed-password123').merge(overrides)
    end
  end

  %w[login password_reset_request password_reset].each do |surface|
    context surface do
      it 'renders a disabled submit button and the matching widget action' do
        path = case surface
        when 'login' then new_session_path
        when 'password_reset_request' then new_password_path
        else edit_password_path(reset_token)
        end
        get path
        expect(response).to have_http_status(:ok)
        html = Nokogiri::HTML(response.body)
        expect(html.at_css('form')['data-turnstile-action-value']).to eq(surface)
        expect(html.at_css('input[type=submit]').key?('disabled')).to be(true)
        expect(response.headers['Cache-Control']).to include('no-store')
      end

      it 'rejects missing tokens without authenticating, sending mail or changing passwords' do
        digest = user.password_digest
        expect(http).not_to receive(:request)
        expect { submit(surface, token: nil) }.not_to change(Session, :count)
        expect(response).to have_http_status(:forbidden)
        expect(response.body).to include('Please complete the human verification again')
        expect(user.reload.password_digest).to eq(digest)
        expect(enqueued_jobs.select { |job| job[:job] == ActionMailer::MailDeliveryJob }).to be_empty
      end

      it 'rejects a valid token issued for another form' do
        approve('signup')
        expect { submit(surface) }.not_to change(Session, :count)
        expect(response).to have_http_status(:forbidden)
        expect(user.reload.authenticate('password')).to eq(user)
        expect(enqueued_jobs.select { |job| job[:job] == ActionMailer::MailDeliveryJob }).to be_empty
      end

      it 'rejects expired or replayed tokens' do
        allow(reply).to receive(:body).and_return({ success: false, 'error-codes' => [ 'timeout-or-duplicate' ] }.to_json)
        submit(surface)
        expect(response).to have_http_status(:forbidden)
      end

      it 'fails closed on outages and missing configuration' do
        allow(http).to receive(:request).and_raise(Net::ReadTimeout)
        submit(surface)
        expect(response).to have_http_status(:forbidden)
        expect(response.body).to include('Human verification is temporarily unavailable')
        allow(TurnstileConfig).to receive(:secret).and_return(nil)
        submit(surface)
        expect(response).to have_http_status(:forbidden)
        expect(Nokogiri::HTML(response.body).at_css('input[type=submit]').key?('disabled')).to be(true)
      end
    end
  end

  it 'logs in a verified user and honors the saved destination even when registration is closed' do
    SiteSetting.current.update!(registrations_enabled: false)
    get settings_path
    approve('login')
    expect { submit('login') }.to change(Session, :count).by(1)
    expect(response).to redirect_to(settings_url)
  end

  it 'still rejects incorrect credentials after verification' do
    approve('login')
    expect { submit('login', password: 'wrong-password') }.not_to change(Session, :count)
    expect(response).to redirect_to(new_session_path)
    follow_redirect!
    expect(response.body).to include('Try another email address or password.')
  end

  it 'retains the email but never echoes a password on failed Turbo verification' do
    post session_path, params: { email_address: user.email_address, password: 'do-not-echo' },
      headers: { 'ACCEPT' => 'text/vnd.turbo-stream.html, text/html' }
    expect(response).to have_http_status(:forbidden)
    expect(response.body).to include(user.email_address)
    expect(response.body).not_to include('do-not-echo')
  end

  it 'sends reset mail only after verification and preserves the generic response for unknown addresses' do
    approve('password_reset_request')
    expect { submit('password_reset_request') }.to have_enqueued_mail(PasswordsMailer, :reset).with(user)
    expect(response).to redirect_to(new_session_path)
    notice = flash[:notice]
    expect { submit('password_reset_request', email_address: 'missing@example.com') }.not_to have_enqueued_mail
    expect(flash[:notice]).to eq(notice)
  end

  it 'changes the password and revokes sessions only after verification' do
    user.sessions.create!
    approve('password_reset')
    expect { submit('password_reset') }.to change { user.sessions.count }.to(0)
    expect(response).to redirect_to(new_session_path)
    expect(user.reload.authenticate('changed-password123')).to eq(user)
  end

  it 'preserves the reset link after a verification failure, then permits a fresh token' do
    token = reset_token
    submit('password_reset')
    expect(response).to have_http_status(:forbidden)
    expect(Nokogiri::HTML(response.body).at_css('form')['action']).to eq(password_path(token))
    approve('password_reset')
    submit('password_reset')
    expect(response).to redirect_to(new_session_path)
  end

  it 'retains password validation and invalid-reset-link handling' do
    approve('password_reset')
    submit('password_reset', password_confirmation: 'mismatch')
    expect(response).to redirect_to(edit_password_path(reset_token))
    expect(user.reload.authenticate('password')).to eq(user)
    expect(TurnstileVerifier).not_to receive(:call)
    patch password_path('invalid-token'), params: { password: 'new-password' }
    expect(response).to redirect_to(new_password_path)
  end

  it 'does not require verification to sign out' do
    sign_in_as(user)
    expect(TurnstileVerifier).not_to receive(:call)
    delete session_path
    expect(response).to redirect_to(new_session_path)
  end
end

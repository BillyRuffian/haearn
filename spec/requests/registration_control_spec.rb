require 'rails_helper'

RSpec.describe 'Registration control', type: :request do
  let(:verification_response) { Net::HTTPOK.new('1.1', '200', 'OK') }

  before do
    allow(TurnstileConfig).to receive(:secret).and_return('private-test-secret')
    allow(TurnstileConfig).to receive(:hostnames).and_return([ 'signup.example.com' ])
    allow(verification_response).to receive(:body).and_return({ success: true, action: 'signup', hostname: 'signup.example.com' }.to_json)
    allow_any_instance_of(Net::HTTP).to receive(:request).and_return(verification_response)
  end

  let(:signup_params) do
    { 'cf-turnstile-response' => 'fresh-verification-token', user: { name: 'New Lifter', email_address: 'new-lifter@example.com', password: 'password123',
              password_confirmation: 'password123', preferred_unit: 'kg' } }
  end

  it 'enables registration by default and creates an authenticated account' do
    expect(SiteSetting.current.registrations_enabled?).to be(true)
    get new_registration_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Create Account')

    expect { post registration_path, params: signup_params }
      .to change(User, :count).by(1).and change(Session, :count).by(1)
    expect(response).to redirect_to(root_path)
    expect(User.find_by!(email_address: 'new-lifter@example.com').sessions.count).to eq(1)
  end

  it 'continues showing validation errors when registrations are enabled' do
    expect { post registration_path, params: signup_params.deep_merge(user: { password_confirmation: 'wrong' }) }
      .not_to change(User, :count)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('Create Account', 'Password confirmation')
  end

  it 'shows a closed message and sign-in link without a registration form' do
    SiteSetting.current.update!(registrations_enabled: false)
    get new_registration_path

    expect(response).to have_http_status(:ok)
    expect(response.headers['Cache-Control']).to include('no-store')
    expect(response.body).to include('Registrations are currently closed', 'Please check back later')
    html = Nokogiri::HTML(response.body)
    expect(html.at_css("a[href='#{new_session_path}']")).to be_present
    expect(html.at_css("form[action='#{registration_path}']")).to be_nil
    expect(html.at_css('[data-controller="turnstile"]')).to be_nil
  end

  it 'rejects a form opened before registrations closed without creating a user or session' do
    get new_registration_path
    SiteSetting.current.update!(registrations_enabled: false)
    expect(TurnstileVerifier).not_to receive(:call)

    expect { post registration_path, params: signup_params }
      .to change(User, :count).by(0).and change(Session, :count).by(0)
    expect(response).to have_http_status(:forbidden)
    expect(response.body).to include('Registrations are currently closed')
  end

  it 'rejects Turbo submissions and missing user parameters while closed' do
    SiteSetting.current.update!(registrations_enabled: false)

    expect { post registration_path, headers: { 'ACCEPT' => 'text/vnd.turbo-stream.html, text/html' } }
      .to change(User, :count).by(0).and change(Session, :count).by(0)
    expect(response).to have_http_status(:forbidden)
    expect(response.body).to include('Registrations are currently closed')
  end

  it 'allows existing users to sign in while registrations are closed' do
    SiteSetting.current.update!(registrations_enabled: false)
    expect { sign_in_as(users(:one)) }.to change(Session, :count).by(1)
    expect(response).to redirect_to(root_url)
  end

  it 'requires authentication to change registrations' do
    patch admin_registration_path, params: { site_setting: { registrations_enabled: '0' } }
    expect(response).to redirect_to(new_session_path)
    expect(SiteSetting.current.registrations_enabled?).to be(true)
  end

  it 'prevents non-admins from changing registrations' do
    sign_in_as(users(:one))
    expect do
      patch admin_registration_path, params: { site_setting: { registrations_enabled: '0' } }
    end.not_to change(AdminAuditLog, :count)
    expect(response).to redirect_to(root_path)
    expect(SiteSetting.current.registrations_enabled?).to be(true)
  end

  it 'persists both admin switch states and audits each change' do
    sign_in_as(users(:admin))
    [ '0', '1' ].each do |value|
      expect do
        patch admin_registration_path, params: { site_setting: { registrations_enabled: value } }
      end.to change(AdminAuditLog, :count).by(1)
      expect(response).to redirect_to(admin_root_path)
      enabled = value == '1'
      expect(SiteSetting.current.registrations_enabled?).to be(enabled)
      log = AdminAuditLog.order(:id).last
      expect(log.admin_user).to eq(users(:admin))
      expect(log.action).to eq('update_registration_settings')
      expect(log.metadata).to include('registrations_enabled' => enabled, 'previous_registrations_enabled' => !enabled)

      get admin_root_path
      expect(response).to have_http_status(:ok)
      switch = Nokogiri::HTML(response.body).at_css('input[role="switch"]')
      expect(switch.key?('checked')).to be(enabled)
    end

    delete session_path
    expect { post registration_path, params: signup_params }.to change(User, :count).by(1)
  end

  it 'rejects missing or invalid settings without changing the saved value' do
    sign_in_as(users(:admin))
    [ {}, { registrations_enabled: 'invalid' } ].each do |attributes|
      patch admin_registration_path, params: { site_setting: attributes }
      expect(response).to have_http_status(:bad_request)
      expect(SiteSetting.current.registrations_enabled?).to be(true)
    end
  end

  it 'rejects a direct sign-up without human verification and preserves non-password inputs' do
    expect { post registration_path, params: signup_params.except('cf-turnstile-response') }
      .to change(User, :count).by(0).and change(Session, :count).by(0)
    expect(response).to have_http_status(:forbidden)
    expect(response.body).to include('Please complete the human verification again', 'new-lifter@example.com')
    expect(response.body).not_to include('password123')
  end

  it 'rejects invalid, expired or replayed verification, including Turbo submissions' do
    allow(verification_response).to receive(:body).and_return({ success: false, 'error-codes' => [ 'timeout-or-duplicate' ] }.to_json)
    expect do
      post registration_path, params: signup_params, headers: { 'ACCEPT' => 'text/vnd.turbo-stream.html, text/html' }
    end.to change(User, :count).by(0).and change(Session, :count).by(0)
    expect(response).to have_http_status(:forbidden)
    expect(response.body).to include('Please complete the human verification again')
  end

  it 'fails closed with a helpful message when configuration is missing' do
    allow(TurnstileConfig).to receive(:secret).and_return(nil)
    get new_registration_path
    expect(response.body).to include('Human verification is temporarily unavailable')
    expect(Nokogiri::HTML(response.body).at_css('input[type="submit"]').key?('disabled')).to be(true)

    expect { post registration_path, params: signup_params }
      .to change(User, :count).by(0).and change(Session, :count).by(0)
    expect(response).to have_http_status(:forbidden)
  end

  it 'blocks account creation when the verification service times out' do
    allow_any_instance_of(Net::HTTP).to receive(:request).and_raise(Net::ReadTimeout)
    expect { post registration_path, params: signup_params }
      .to change(User, :count).by(0).and change(Session, :count).by(0)
    expect(response).to have_http_status(:forbidden)
    expect(response.body).to include('Human verification is temporarily unavailable')
  end

  it 'filters verification tokens from request logging' do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    expect(filter.filter('cf-turnstile-response' => 'secret-token')).to eq('cf-turnstile-response' => '[FILTERED]')
  end
end

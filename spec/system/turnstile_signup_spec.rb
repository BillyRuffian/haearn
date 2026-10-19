require 'rails_helper'

RSpec.describe 'Sign-up human verification', type: :system, js: true do
  before do
    allow(TurnstileConfig).to receive(:secret).and_return('private-test-secret')
    allow(TurnstileConfig).to receive(:hostnames).and_return([ 'signup.example.com' ])
    reply = Net::HTTPOK.new('1.1', '200', 'OK')
    allow(reply).to receive(:body).and_return({ success: true, action: 'signup', hostname: 'signup.example.com' }.to_json)
    http = Net::HTTP.new('challenges.cloudflare.com', 443)
    allow(Net::HTTP).to receive(:new).and_call_original
    allow(Net::HTTP).to receive(:new).with('challenges.cloudflare.com', 443).and_return(http)
    allow(http).to receive(:request).and_return(reply)
  end

  it 'requires verification again after validation errors and supports Turbo navigation' do
    visit new_session_path
    page.execute_script(<<~JS)
      window.testWidgets = [];
      window.turnstile = {
        render(element, options) {
          const input = document.createElement('input');
          input.type = 'hidden';
          input.name = 'cf-turnstile-response';
          element.appendChild(input);
          return window.testWidgets.push({ input, options }) - 1;
        },
        reset(id) { window.testWidgets[id].input.value = ''; },
        remove(id) { window.testWidgets[id].input.remove(); }
      };
      window.verifySignup = () => {
        const widget = window.testWidgets.at(-1);
        widget.input.value = 'browser-test-token';
        widget.options.callback('browser-test-token');
      };
      Turbo.visit(#{new_registration_path.to_json});
    JS

    expect(page).to have_button('Create Account', disabled: true)
    expect(page).to have_css('input[name="cf-turnstile-response"]', visible: false)
    fill_in 'Name', with: 'Browser Lifter'
    fill_in 'Email', with: 'turnstile-browser@example.com'
    fill_in 'Password', with: 'password123', exact: true
    fill_in 'Confirm password', with: 'wrong-password'
    page.execute_script('window.verifySignup()')
    expect(page).to have_button('Create Account', disabled: false)
    click_button 'Create Account'

    expect(page).to have_content("Password confirmation doesn't match")
    expect(page).to have_button('Create Account', disabled: true)
    expect(page).to have_field('Email', with: 'turnstile-browser@example.com')
    expect(User.exists?(email_address: 'turnstile-browser@example.com')).to be(false)
    expect(page).to have_css('input[name="cf-turnstile-response"]', visible: false)
    page.execute_script('window.verifySignup()')
    expect(page).to have_button('Create Account', disabled: false)

    page.execute_script('window.testWidgets.at(-1).options["expired-callback"]()')
    expect(page).to have_button('Create Account', disabled: true)
    page.execute_script('window.verifySignup()')
    fill_in 'Password', with: 'password123', exact: true
    fill_in 'Confirm password', with: 'password123'
    click_button 'Create Account'
    expect(page).to have_content("Welcome to Haearn! Let's get lifting.")
    expect(User.find_by!(email_address: 'turnstile-browser@example.com').sessions.count).to eq(1)
  end
end

require 'rails_helper'

RSpec.describe 'Login and password reset verification', type: :system, js: true do
  before do
    allow(TurnstileConfig).to receive(:secret).and_return(nil)
    allow(TurnstileConfig).to receive(:hostnames).and_return([ 'www.haearn.com' ])
    visit new_session_path
    allow(TurnstileConfig).to receive(:secret).and_return('private-test-secret')
    http = Net::HTTP.new('challenges.cloudflare.com', 443)
    allow(Net::HTTP).to receive(:new).and_call_original
    allow(Net::HTTP).to receive(:new).with('challenges.cloudflare.com', 443).and_return(http)
    allow(http).to receive(:request) do |request|
      token = URI.decode_www_form(request.body).to_h.fetch('response')
      reply = Net::HTTPOK.new('1.1', '200', 'OK')
      allow(reply).to receive(:body).and_return({ success: true, action: token, hostname: 'www.haearn.com' }.to_json)
      reply
    end
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
      window.verifyHuman = () => {
        const widget = window.testWidgets.at(-1);
        widget.input.value = widget.options.action;
        widget.options.callback(widget.input.value);
      };
      Turbo.visit(#{new_session_path.to_json});
    JS
  end

  def complete_verification(action, button)
    expect(page).to have_button(button, disabled: true)
    expect(page).to have_css('input[name="cf-turnstile-response"]', visible: false)
    expect(page.evaluate_script('window.testWidgets.at(-1).options.action')).to eq(action)
    page.execute_script('window.verifyHuman()')
    expect(page).to have_button(button, disabled: false)
  end

  it 'requires a fresh login verification after incorrect credentials' do
    fill_in 'Email', with: users(:system).email_address
    fill_in 'Password', with: 'wrong-password'
    complete_verification('login', 'Sign In')
    click_button 'Sign In'
    expect(page).to have_content('Try another email address or password.')
    fill_in 'Email', with: users(:system).email_address
    fill_in 'Password', with: 'password'
    complete_verification('login', 'Sign In')
    click_button 'Sign In'
    expect(page).to have_current_path(root_path)
    expect(page).not_to have_button('Sign In')
  end

  it 'verifies reset requests and password changes with their own actions' do
    click_link 'Forgot password?'
    fill_in 'Email', with: users(:system).email_address
    complete_verification('password_reset_request', 'Send Reset Instructions')
    click_button 'Send Reset Instructions'
    expect(page).to have_content('Password reset instructions sent')

    token = users(:system).password_reset_token
    page.execute_script('Turbo.visit(arguments[0])', edit_password_path(token))
    fill_in 'New Password', with: 'new-password123'
    fill_in 'Confirm Password', with: 'mismatch'
    complete_verification('password_reset', 'Update Password')
    click_button 'Update Password'
    expect(page).to have_content('Passwords did not match.')
    fill_in 'New Password', with: 'new-password123'
    fill_in 'Confirm Password', with: 'new-password123'
    complete_verification('password_reset', 'Update Password')
    click_button 'Update Password'
    expect(page).to have_content('Password has been reset.')
    expect(users(:system).reload.authenticate('new-password123')).to eq(users(:system))
  end
end

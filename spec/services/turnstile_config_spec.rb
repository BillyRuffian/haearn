require 'rails_helper'

RSpec.describe TurnstileConfig do
  before do
    allow(ENV).to receive(:[]).and_call_original
    %w[TURNSTILE_SITE_KEY TURNSTILE_SECRET TURNSTILE_HOSTNAMES].each do |key|
      allow(ENV).to receive(:[]).with(key).and_return(nil)
    end
    allow(Rails.application.credentials).to receive(:dig).with(:turnstile, :site_key).and_return(nil)
    allow(Rails.application.credentials).to receive(:dig).with(:turnstile, :secret).and_return('credential-secret')
    allow(Rails.application.credentials).to receive(:dig).with(:turnstile, :hostnames).and_return('www.haearn.com')
  end

  it 'uses the supplied public site key and supports Rails credentials' do
    expect(described_class.site_key).to eq('0x4AAAAAAFcD0V7zv061YNIK')
    expect(described_class.secret).to eq('credential-secret')
    expect(described_class.configured?).to be(true)
  end

  it 'allows environment overrides and trims the explicit hostname allowlist' do
    allow(ENV).to receive(:[]).with('TURNSTILE_SECRET').and_return('env-secret')
    allow(ENV).to receive(:[]).with('TURNSTILE_SITE_KEY').and_return('env-site-key')
    allow(ENV).to receive(:[]).with('TURNSTILE_HOSTNAMES').and_return(' www.haearn.com, ,www.haearn.com ')
    expect(described_class.secret).to eq('env-secret')
    expect(described_class.site_key).to eq('env-site-key')
    expect(described_class.hostnames).to eq([ 'www.haearn.com' ])
  end

  it 'requires an explicit deployment hostname list' do
    allow(Rails.application.credentials).to receive(:dig).with(:turnstile, :hostnames).and_return(nil)
    expect(described_class.configured?).to be(false)
  end

  it 'rejects local hostnames in production even if combined with the production domain' do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
    allow(ENV).to receive(:[]).with('TURNSTILE_HOSTNAMES').and_return('www.haearn.com,localhost')
    expect(described_class.configured?).to be(false)
  end
end

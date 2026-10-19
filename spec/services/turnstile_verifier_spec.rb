require 'rails_helper'

RSpec.describe TurnstileVerifier do
  let(:http) { Net::HTTP.new('challenges.cloudflare.com', 443) }
  let(:reply) { Net::HTTPOK.new('1.1', '200', 'OK') }
  let(:result) { { success: true, action: 'signup', hostname: 'www.haearn.com' } }

  before do
    allow(TurnstileConfig).to receive(:secret).and_return('private-test-secret')
    allow(TurnstileConfig).to receive(:hostnames).and_return([ 'www.haearn.com' ])
    http
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(reply).to receive(:body) { result.to_json }
    allow(http).to receive(:request).and_return(reply)
  end

  def verify(token = 'fresh-token')
    described_class.call(token: token, remote_ip: '192.0.2.1')
  end

  it 'verifies via HTTPS with the secret, token, client IP and bounded timeouts' do
    expect(http).to receive(:request) do |request|
      expect(request.path).to eq('/turnstile/v0/siteverify')
      expect(URI.decode_www_form(request.body).to_h).to eq(
        'secret' => 'private-test-secret', 'response' => 'fresh-token', 'remoteip' => '192.0.2.1'
      )
      reply
    end
    expect(verify).to eq(:verified)
    expect(http.use_ssl?).to be(true)
    expect([ http.open_timeout, http.read_timeout, http.write_timeout, http.max_retries ]).to eq([ 3, 5, 3, 0 ])
  end

  it 'rejects missing, malformed and oversized tokens before making a network request' do
    expect(http).not_to receive(:request)
    [ nil, '', ' ', [], {}, 'a' * 2049 ].each { |token| expect(verify(token)).to eq(:invalid) }
  end

  it 'requires a true boolean success, exact signup action and approved hostname' do
    [ { success: false }, { success: 'true' }, { action: 'login' }, { action: nil },
      { hostname: 'localhost' }, { hostname: 'www.haearn.com.attacker.test' }, { hostname: nil } ].each do |invalid|
      allow(reply).to receive(:body).and_return(result.merge(invalid).to_json)
      expect(verify).to eq(:invalid)
    end
  end

  it 'rejects expired and replayed tokens' do
    allow(reply).to receive(:body).and_return({ success: false, 'error-codes' => [ 'timeout-or-duplicate' ] }.to_json)
    expect(verify).to eq(:invalid)
  end

  it 'fails closed when the secret or expected hostnames are missing' do
    expect(http).not_to receive(:request)
    allow(TurnstileConfig).to receive(:secret).and_return(nil)
    expect(verify).to eq(:unavailable)
    allow(TurnstileConfig).to receive(:secret).and_return('private-test-secret')
    allow(TurnstileConfig).to receive(:hostnames).and_return([])
    expect(verify).to eq(:unavailable)
  end

  it 'handles network failures without revealing tokens or secrets' do
    [ Net::ReadTimeout, SocketError, OpenSSL::SSL::SSLError, EOFError ].each do |error|
      allow(http).to receive(:request).and_raise(error)
      expect(verify).to eq(:unavailable)
    end
  end

  it 'fails closed on server errors, malformed JSON and invalid secrets' do
    allow(http).to receive(:request).and_return(Net::HTTPServiceUnavailable.new('1.1', '503', 'Unavailable'))
    expect(verify).to eq(:unavailable)
    allow(http).to receive(:request).and_return(reply)
    [ '<html>Error</html>', 'null', '[]', { success: false, 'error-codes' => [ 'invalid-input-secret' ] }.to_json ].each do |body|
      allow(reply).to receive(:body).and_return(body)
      expect(verify).to eq(:unavailable)
    end
  end
end

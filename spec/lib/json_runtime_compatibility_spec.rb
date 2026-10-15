require 'rails_helper'

RSpec.describe 'JSON runtime compatibility' do
  it 'decodes JSON through Active Support without parser options' do
    expect(ActiveSupport::JSON.decode('{"active":true}')).to eq('active' => true)
  end

  it 'forwards parser options as keywords for JSON 3 on Ruby 4' do
    expect(ActiveSupport::JSON.decode('{"active":true}', symbolize_names: true)).to eq(active: true)
  end

  it 'round-trips signed JSON payloads used by session and reset tokens' do
    verifier = ActiveSupport::MessageVerifier.new('test-only-json-key', serializer: :json)
    payload = { 'user_id' => 42, 'active' => true }

    expect(verifier.verify(verifier.generate(payload))).to eq(payload)
  end
end

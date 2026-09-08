require 'rails_helper'

RSpec.describe 'JSON runtime compatibility' do
  it 'decodes JSON through Active Support with parser options' do
    expect(ActiveSupport::JSON.decode('{"active":true}')).to eq('active' => true)
  end
end

require 'rails_helper'

RSpec.describe 'libvips initializer' do
  subject(:load_initializer) { load Rails.root.join('config/initializers/libvips_version.rb') }

  it 'blocks untrusted operations after accepting the installed libvips version' do
    allow(Vips).to receive(:version_string).and_return('8.13.0')
    allow(Vips).to receive(:block_untrusted)

    load_initializer

    expect(Vips).to have_received(:block_untrusted).with(true)
  end

  it 'rejects an old libvips version before calling its security API' do
    allow(Vips).to receive(:version_string).and_return('8.12.0')
    allow(Vips).to receive(:block_untrusted)

    expect { load_initializer }
      .to raise_error(RuntimeError, 'libvips >= 8.13.0 is required for Active Storage variants, found 8.12.0')
    expect(Vips).not_to have_received(:block_untrusted)
  end
end

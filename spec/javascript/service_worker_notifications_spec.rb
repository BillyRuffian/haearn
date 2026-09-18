require 'spec_helper'
require 'open3'

RSpec.describe 'Service worker notification lifecycle' do
  it 'runs the real worker event handlers against push, read, offline, and authentication scenarios' do
    output, status = Open3.capture2e('node', '--test', File.expand_path('service_worker_notifications_test.cjs', __dir__))
    expect(status.success?).to be(true), output
  end
end

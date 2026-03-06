require 'capybara/rspec'
require 'selenium/webdriver'
require 'socket'

module SystemDriverSupport
  module_function

  def js_system_supported?
    browser_available? && socket_binding_available?
  end

  def browser_available?
    File.executable?(ENV.fetch('CHROME_BIN', '/usr/bin/chromium-browser')) && !chromedriver_path.empty?
  end

  def chromedriver_path
    ENV.fetch('CHROMEDRIVER_BIN', `which chromedriver 2>/dev/null`.strip)
  end

  def socket_binding_available?
    server = TCPServer.new('127.0.0.1', 0)
    server.close
    true
  rescue Errno::EPERM, Errno::EACCES, SocketError
    false
  end
end

Capybara.register_driver :selenium_chromium_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.binary = ENV.fetch('CHROME_BIN', '/usr/bin/chromium-browser')
  options.add_argument('--headless=new')
  options.add_argument('--disable-gpu')
  options.add_argument('--no-sandbox')
  options.add_argument('--window-size=1400,1400')

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, type: :system, js: true) do
    skip 'JS system specs are unavailable in this environment' unless SystemDriverSupport.js_system_supported?
    driven_by :selenium_chromium_headless
  end
end

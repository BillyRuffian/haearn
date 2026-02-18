# frozen_string_literal: true

require 'openssl'
require 'base64'

namespace :web_push do
  desc 'Generate VAPID keys compatible with OpenSSL 3 and print env exports'
  task generate_keys: :environment do
    ec = OpenSSL::PKey::EC.generate('prime256v1')
    public_key_bytes = ec.public_key.to_octet_string(:uncompressed)
    private_key_bytes = ec.private_key.to_s(2).rjust(32, "\x00")

    encode = lambda do |bytes|
      Base64.strict_encode64(bytes).tr('+/', '-_').delete('=')
    end

    puts 'VAPID key pair generated.'
    puts
    puts "export VAPID_PUBLIC_KEY='#{encode.call(public_key_bytes)}'"
    puts "export VAPID_PRIVATE_KEY='#{encode.call(private_key_bytes)}'"
    puts "export VAPID_SUBJECT='mailto:you@example.com'"
    puts
    puts 'You can set these in ENV or Rails credentials under web_push.{public_key,private_key,subject}.'
  end
end

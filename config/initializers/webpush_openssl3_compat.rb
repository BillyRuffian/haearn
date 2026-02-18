# frozen_string_literal: true

# OpenSSL 3 compatibility for webpush 1.1.x.
# The gem's default VAPID key paths mutate EC keys via `public_key=`/`private_key=`
# and `generate_key`, which raise `pkeys are immutable on OpenSSL 3.0`.
#
# This patch rebuilds keys through JWT JWK import / OpenSSL::PKey.read and avoids
# mutating immutable EC key objects.
begin
  require 'webpush'
  require 'jwt'

  module Webpush
    class VapidKey
      class << self
        def from_keys(public_key, private_key)
          pub = Webpush.decode64(public_key)
          x = Webpush.encode64(pub.byteslice(1, 32))
          y = Webpush.encode64(pub.byteslice(33, 32))

          jwk = JWT::JWK.import(
            {
              kty: 'EC',
              crv: 'P-256',
              x: x,
              y: y,
              d: private_key
            }
          )

          key = allocate
          key.instance_variable_set(:@curve, jwk.signing_key)
          key
        end

        def from_pem(pem)
          key = allocate
          key.instance_variable_set(:@curve, OpenSSL::PKey.read(pem))
          key
        end
      end

      def initialize
        @curve = OpenSSL::PKey::EC.generate('prime256v1')
      end
    end

    # Build VAPID authorization header without instantiating/mutating EC keys
    # through Webpush::VapidKey internals (which can fail on OpenSSL 3).
    class Request
      def build_vapid_header
        pub = Webpush.decode64(vapid_public_key)
        x = Webpush.encode64(pub.byteslice(1, 32))
        y = Webpush.encode64(pub.byteslice(33, 32))

        jwk = JWT::JWK.import(
          {
            kty: 'EC',
            crv: 'P-256',
            x: x,
            y: y,
            d: vapid_private_key
          }
        )

        jwt = JWT.encode(jwt_payload, jwk.signing_key, 'ES256', jwt_header_fields)
        p256ecdsa = vapid_public_key.delete('=')

        "vapid t=#{jwt},k=#{p256ecdsa}"
      end
    end

    module Encryption
      class << self
        # OpenSSL 3-safe variant of webpush encryption key generation.
        def encrypt(message, p256dh, auth)
          assert_arguments(message, p256dh, auth)

          group_name = 'prime256v1'
          salt = Random.new.bytes(16)

          server = OpenSSL::PKey::EC.generate(group_name)
          server_public_key_bn = server.public_key.to_bn

          group = OpenSSL::PKey::EC::Group.new(group_name)
          client_public_key_bn = OpenSSL::BN.new(Webpush.decode64(p256dh), 2)
          client_public_key = OpenSSL::PKey::EC::Point.new(group, client_public_key_bn)

          shared_secret = server.dh_compute_key(client_public_key)
          client_auth_token = Webpush.decode64(auth)

          info = "WebPush: info\0" + client_public_key_bn.to_s(2) + server_public_key_bn.to_s(2)
          content_encryption_key_info = "Content-Encoding: aes128gcm\0"
          nonce_info = "Content-Encoding: nonce\0"

          prk = HKDF.new(shared_secret, salt: client_auth_token, algorithm: 'SHA256', info: info).next_bytes(32)
          content_encryption_key = HKDF.new(prk, salt: salt, info: content_encryption_key_info).next_bytes(16)
          nonce = HKDF.new(prk, salt: salt, info: nonce_info).next_bytes(12)

          ciphertext = encrypt_payload(message, content_encryption_key, nonce)

          serverkey16bn = convert16bit(server_public_key_bn)
          rs = ciphertext.bytesize
          raise ArgumentError, 'encrypted payload is too big' if rs > 4096

          aes128gcmheader = "#{salt}" + [ rs ].pack('N*') + [ serverkey16bn.bytesize ].pack('C*') + serverkey16bn
          aes128gcmheader + ciphertext
        end
      end
    end
  end
rescue LoadError
  # webpush/jwt gems unavailable in this environment
end

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
  end
rescue LoadError
  # webpush/jwt gems unavailable in this environment
end

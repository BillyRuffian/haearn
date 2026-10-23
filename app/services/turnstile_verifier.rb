require 'net/http'

class TurnstileVerifier
  ENDPOINT = URI('https://challenges.cloudflare.com/turnstile/v0/siteverify')

  def self.call(token:, remote_ip:, expected_action:)
    new.call(token: token, remote_ip: remote_ip, expected_action: expected_action)
  end

  def call(token:, remote_ip:, expected_action:)
    return :unavailable unless TurnstileConfig.configured?
    return :invalid unless token.is_a?(String) && token.present? && token.length <= 2048

    http = Net::HTTP.new(ENDPOINT.host, ENDPOINT.port)
    http.use_ssl = true
    http.open_timeout = 3
    http.read_timeout = 5
    http.write_timeout = 3
    http.max_retries = 0

    request = Net::HTTP::Post.new(ENDPOINT)
    request.set_form_data(secret: TurnstileConfig.secret, response: token, remoteip: remote_ip)
    response = http.request(request)
    return :unavailable unless response.is_a?(Net::HTTPSuccess)

    result = JSON.parse(response.body)
    return :unavailable unless result.is_a?(Hash)
    return :unavailable if (Array(result['error-codes']) & %w[missing-input-secret invalid-input-secret internal-error]).any?

    if result['success'] == true && result['action'] == expected_action && TurnstileConfig.hostnames.include?(result['hostname'])
      :verified
    else
      :invalid
    end
  rescue Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError, JSON::ParserError, Net::HTTPBadResponse
    :unavailable
  end
end

class Rack::Attack
  # Throttle all requests by IP (60rpm)
  throttle('req/ip', limit: 300, period: 5.minutes) do |req|
    req.ip
  end

  # Throttle login attempts for a given email parameter to 6 RPM
  throttle('logins/email', limit: 6, period: 60.seconds) do |req|
    if req.path == '/users/sign_in' && req.post?
      # Normalize email address by downcasing it
      req.params['user'] && req.params['user']['email'].to_s.downcase
    end
  end

  # Throttle signup attempts for a given email parameter to 6 RPM
  throttle('signups/email', limit: 6, period: 60.seconds) do |req|
    if req.path == '/users' && req.post?
      # Normalize email address by downcasing it
      req.params['user'] && req.params['user']['email'].to_s.downcase
    end
  end

  # Block suspicious requests containing common attack patterns
  blocklist('block suspicious requests') do |req|
    Rack::Attack::BadRequestMatcher.match?(req)
  end

  class BadRequestMatcher
    def self.match?(request)
      path = request.path.downcase
      
      # Block requests with suspicious SQL fragments
      request.params.values.any? { |v| v.to_s =~ /(\%27)|(\')|(\-\-)|(\%23)|(#)/i } ||
      
      # Block requests attempting path traversal
      request.params.values.any? { |v| v.to_s =~ /(\.\.\/)/i }
    end
  end

  # Custom response for throttled requests
  self.throttled_responder = lambda do |request|
    match_data = request.env['rack.attack.match_data']
    now = Time.now
    
    headers = {
      'Content-Type' => 'application/json',
      'Retry-After' => (match_data[:period] - (now.to_i % match_data[:period])).to_s
    }
    
    [429, headers, [{ error: "Too many requests. Please try again later." }.to_json]]
  end
end 
class Rack::Attack
  # Replace safelist with throttle for document uploads
  # This allows document uploads but with a higher limit than regular requests
  throttle('document uploads', limit: 20, period: 5.minutes) do |req|
    if req.path == '/assistants/upload_document' && req.post?
      req.ip
    end
  end

  # Throttle all requests by IP (300rpm) - high enough for legitimate users, but will catch aggressive bots
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

  # Throttle chat endpoint requests by IP to 30 requests per minute
  throttle('api/v1/chat', limit: 10, period: 60.seconds) do |req|
    if req.path.start_with?('/api/v1/chat') && req.post?
      req.ip
    end
  end

  # Throttle last_messages endpoint requests by IP to 60 requests per minute
  throttle('api/v1/chat/last_messages', limit: 10, period: 60.seconds) do |req|
    if req.path.match?(%r{/api/v1/chat/.+/last_messages}) && req.get?
      req.ip
    end
  end

  throttle('api/excessive-requests', limit: 15, period: 1.minute) do |req|
    if req.path.start_with?('/api/v1/chat')
      req.ip
    end
  end

  throttle('api/excessive-requests', limit: 25, period: 2.minutes) do |req|
    if req.path.start_with?('/api/v1/chat')
      req.ip
    end
  end

  throttle('api/excessive-requests', limit: 50, period: 5.minutes) do |req|
    if req.path.start_with?('/api/v1/chat')
      req.ip
    end
  end

  # Block IPs that have been flagged as abusive
  blocklist('block suspicious API requests') do |req|
    # Check if this IP has been blocked
    if req.path.start_with?('/api/v1/chat')
      key = "api/block-candidates/ip:#{req.ip}_block"
      Rack::Attack.cache.store.read(key)
    end
  end

  # Helper method to block an IP
  def self.block_ip(ip, duration = 24.hours)
    key = "api/block-candidates/ip:#{ip}_block"
    Rack::Attack.cache.store.write(key, true, expires_in: duration)
  end

  # Set up a subscriber to block IPs that trigger the excessive-requests throttle
  ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |name, start, finish, request_id, payload|
    if payload[:request].env["rack.attack.matched"] == "api/excessive-requests" && payload[:request].env["rack.attack.match_type"] == :throttle
      # Block the IP for 1 hour after hitting the rate limit
      ip = payload[:request].ip
      Rack::Attack.block_ip(ip, 24.hours)
    end
  end

  # Block suspicious requests containing common attack patterns
  blocklist('block suspicious requests') do |req|
    Rack::Attack::BadRequestMatcher.match?(req)
  end

  class BadRequestMatcher
    def self.match?(request)
      path = request.path.downcase
      
      # Skip validation for document uploads (handled in controller)
      return false if path.start_with?('/assistants/upload_document')
      
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
    }
    
    [429, headers, [{ error: "Too many requests. Please try again later." }.to_json]]
  end

  # Custom response for blocked requests
  self.blocklisted_responder = lambda do |request|
    headers = { 'Content-Type' => 'application/json' }
    [403, headers, [{ error: "Access denied. Your IP has been blocked due to suspicious activity. Please contact support if you believe this is an error." }.to_json]]
  end
end 
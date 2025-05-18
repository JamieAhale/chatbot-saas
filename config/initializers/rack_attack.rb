class Rack::Attack
  # Comment out IP-based rate limiting
  # Replace safelist with throttle for document uploads
  # This allows document uploads but with a higher limit than regular requests
  # throttle('document uploads', limit: 20, period: 5.minutes) do |req|
  #   if req.path == '/assistants/upload_document' && req.post?
  #     req.ip
  #   end
  # end

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

  # Helper method to extract visitor ID from request body
  def self.extract_visitor_id_from_body(req)
    visitor_id = nil
    begin
      if req.body.respond_to?(:rewind)
        req.body.rewind
        body = req.body.read
        req.body.rewind
        
        if body.present?
          json_body = JSON.parse(body)
          visitor_id = json_body['visitor_id'] if json_body.is_a?(Hash)
        end
      end
    rescue => e
      Rails.logger.error("Error extracting visitor_id: #{e.message}")
    end
    visitor_id
  end

  # Block all API requests without a valid fingerprint
  # This just immediately blocks the request, but does not add them to a blocklist
  blocklist('require fingerprint') do |req|
    if req.path.start_with?('/api/v1/chat') && req.post?
      visitor_id = extract_visitor_id_from_body(req)
      visitor_id.blank?
    end
  end

  # FingerprintJS throttling for chat endpoint - throttle by visitor ID
  throttle('api/v1/chat/fingerprint', limit: 20, period: 60.seconds) do |req|
    if req.path.start_with?('/api/v1/chat') && req.post?
      # Extract the visitor_id from the request body
      visitor_id = extract_visitor_id_from_body(req)

      "visitor:#{visitor_id}" if visitor_id.present?
    end
  end

  # Block visitors by FingerprintJS visitor ID
  blocklist('block suspicious visitors') do |req|
    if req.path.start_with?('/api/v1/chat')
      visitor_id = extract_visitor_id_from_body(req)

      if visitor_id.present?
        key = "api/block-candidates/visitor:#{visitor_id}_block"
        Rack::Attack.cache.store.read(key)
      end
    end
  end

  # Track excessive requests by FingerprintJS visitor ID
  throttle('api/excessive-requests/fingerprint', limit: 30, period: 5.minutes) do |req|
    if req.path.start_with?('/api/v1/chat')
      visitor_id = extract_visitor_id_from_body(req)
      "visitor:#{visitor_id}" if visitor_id.present?
    end
  end

  # Helper method to block a visitor ID
  def self.block_visitor(visitor_id, duration = 24.hours)
    key = "api/block-candidates/visitor:#{visitor_id}_block"
    Rack::Attack.cache.store.write(key, true, expires_in: duration)
  end
    
  # Block visitor IDs that trigger excessive requests
  ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |name, start, finish, request_id, payload|
    # Block visitor IDs that trigger excessive requests
    if payload[:request].env["rack.attack.matched"] == "api/excessive-requests/fingerprint" && payload[:request].env["rack.attack.match_type"] == :throttle
      begin
        # Extract the throttle discriminator which contains the visitor ID
        discriminator = payload[:request].env["rack.attack.match_discriminator"]
        if discriminator && discriminator.start_with?("visitor:")
          visitor_id = discriminator.sub("visitor:", "")
          Rack::Attack.block_visitor(visitor_id, 24.hours) if visitor_id.present?
          Rollbar.info("Blocked visitor due to excessive requests", 
            visitor_id: visitor_id,
            duration: "24 hours",
            event: 'throttle.rack_attack'
          )
        end
      rescue => e
        Rollbar.warning(e, 
          discriminator: discriminator, 
          visitor_id: visitor_id,
          event: 'throttle.rack_attack'
        )
        Rails.logger.error("Error blocking visitor ID: #{e.message}")
      end
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
    
    # Check if this is a fingerprint-related block
    if request.env['rack.attack.matched'] == 'require fingerprint'
      [403, headers, [{ 
        error: "JavaScript must be enabled to use this service. FingerprintJS is required for security purposes." 
      }.to_json]]
    else
      [403, headers, [{ 
        error: "Access denied. Your access has been blocked due to suspicious activity." 
      }.to_json]]
    end
  end

  # For debugging - log all blocklist matches in development
  if Rails.env.development?
    ActiveSupport::Notifications.subscribe("rack.attack") do |name, start, finish, request_id, payload|
      req = payload[:request]
      if req && payload[:match_type] == :blocklist
        matched_rule = payload[:matched]
        path = req.path rescue "unknown"
        ip = req.ip rescue "unknown"
        Rails.logger.warn "RACK ATTACK: Request blocked by rule #{matched_rule} - Path: #{path}, IP: #{ip}"
      elsif req && payload[:match_type] == :throttle
        matched_rule = payload[:matched]
        path = req.path rescue "unknown"
        ip = req.ip rescue "unknown"
        Rails.logger.warn "RACK ATTACK: Request throttled by rule #{matched_rule} - Path: #{path}, IP: #{ip}"
      end
    end
  end

  # Skip throttling in development environment
  if Rails.env.development?
    throttle('logins/email', limit: 6, period: 60.seconds) do |req|
      if req.path == '/users/sign_in' && req.post?
        # Normalize email address by downcasing it
        req.params['user'] && req.params['user']['email'].to_s.downcase
      end
    end

    throttle('signups/email', limit: 6, period: 60.seconds) do |req|
      if req.path == '/users' && req.post?
        # Normalize email address by downcasing it
        req.params['user'] && req.params['user']['email'].to_s.downcase
      end
    end
  end
end 
require 'redis'

redis_url = ENV.fetch('REDIS_URL') { 'redis://localhost:6379/1' }

# Configure Redis connection
$redis = if redis_url.start_with?('rediss://')
  # For SSL/TLS connections (production)
  Redis.new(
    url: redis_url,
    ssl_params: {
      verify_mode: OpenSSL::SSL::VERIFY_NONE  # Required for Heroku Redis self-signed certs
    },
    timeout: 5.0,
    reconnect_attempts: 3
  )
else
  # For non-SSL connections (development)
  Redis.new(url: redis_url)
end

# Verify connection
begin
  $redis.ping
rescue Redis::BaseConnectionError => error
  Rails.logger.error("Failed to connect to Redis: #{error.inspect}")
  raise error
end 
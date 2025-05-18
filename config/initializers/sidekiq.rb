redis_url = ENV.fetch('REDIS_URL') { 'redis://localhost:6379/1' }

# NOTE: Heroku Redis Mini uses self-signed certs, requiring verify_mode: VERIFY_NONE.
# If you upgrade to a Standard plan, remove ssl_params and switch to redis:// on port 6379.

redis_config = if redis_url.start_with?('rediss://')
  {
    url: redis_url,
    ssl_params: {
      verify_mode: OpenSSL::SSL::VERIFY_NONE  # Required for Heroku Redis self-signed certs
    },
    timeout: 5.0,
    reconnect_attempts: 3
  }
else
  { url: redis_url }
end

Sidekiq.configure_server do |config|
  config.redis = redis_config
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end 
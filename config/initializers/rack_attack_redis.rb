if defined?(Redis) && Rails.env.production?
  redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/1')
  
  # Use Redis as a backing store for Rack::Attack
  redis_config = if redis_url.start_with?('rediss://')
    {
      url: redis_url,
      ssl_params: {
        verify_mode: OpenSSL::SSL::VERIFY_NONE  # Required for Heroku Redis self-signed certs
      },
      timeout: 5.0,
      reconnect_attempts: 3,
      namespace: 'rack_attack',
      expires_in: 1.hour
    }
  else
    {
      url: redis_url,
      namespace: 'rack_attack',
      expires_in: 1.hour
    }
  end

  # Set cache store for Rack::Attack using ActiveSupport::Cache::RedisCacheStore
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(**redis_config)
elsif Rails.env.development?
  # Use memory store for development
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
end 
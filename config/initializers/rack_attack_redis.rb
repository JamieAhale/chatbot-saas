if defined?(Redis) && Rails.env.production?
  # Use Redis as a backing store for Rack::Attack
  redis_config = {
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'),
    namespace: 'rack_attack',
    expires_in: 1.hour
  }

  # Set cache store for Rack::Attack using ActiveSupport::Cache::RedisCacheStore
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(**redis_config)
end 
if defined?(Redis) && Rails.env.production?
  # Use Redis as a backing store for Rack::Attack
  redis_config = RedisConfig.connection_params.merge(
    namespace: 'rack_attack',
    expires_in: 1.hour
  )

  # Set cache store for Rack::Attack using ActiveSupport::Cache::RedisCacheStore
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(**redis_config)
elsif Rails.env.development?
  # Use memory store for development
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
end 
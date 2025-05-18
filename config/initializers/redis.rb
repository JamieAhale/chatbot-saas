require 'redis'

# Configure Redis connection
$redis = Redis.new(**RedisConfig.connection_params)

# Verify connection
begin
  $redis.ping
rescue Redis::BaseConnectionError => error
  Rails.logger.error("Failed to connect to Redis: #{error.inspect}")
  raise error
end 
module RedisConfig
  def self.connection_params
    redis_url = ENV.fetch('REDIS_URL') { 'redis://localhost:6379/1' }
    
    if redis_url.start_with?('rediss://')
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
  end
end 
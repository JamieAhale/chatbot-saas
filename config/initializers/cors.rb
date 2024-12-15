Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*' # You can specify the allowed origins here, e.g., 'http://localhost:3000'
    resource '*',
      headers: :any,
      methods: [:get, :post, :options, :put, :delete]
  end
end
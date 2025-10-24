import Config

# Development configuration
config :couchbase_ex,
  connection_string: "couchbase://localhost",
  username: "Administrator",
  password: "password",
  bucket: "default",
  timeout: 5000,
  pool_size: 5,
  connection_timeout: 10000,
  query_timeout: 30000,
  operation_timeout: 5000

# Enable debug logging in development
config :logger, level: :debug

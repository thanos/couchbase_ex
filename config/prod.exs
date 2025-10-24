import Config

# Production configuration
# In production, these should be set via environment variables
config :couchbase_ex,
  connection_string: System.get_env("COUCHBASE_HOST"),
  username: System.get_env("COUCHBASE_USER"),
  password: System.get_env("COUCHBASE_PASSWORD"),
  bucket: System.get_env("COUCHBASE_BUCKET", "default"),
  timeout: System.get_env("COUCHBASE_TIMEOUT", "5000") |> String.to_integer(),
  pool_size: System.get_env("COUCHBASE_POOL_SIZE", "20") |> String.to_integer(),
  connection_timeout:
    System.get_env("COUCHBASE_CONNECTION_TIMEOUT", "15000") |> String.to_integer(),
  query_timeout: System.get_env("COUCHBASE_QUERY_TIMEOUT", "60000") |> String.to_integer(),
  operation_timeout: System.get_env("COUCHBASE_OPERATION_TIMEOUT", "10000") |> String.to_integer()

# Production logging
config :logger, level: :info

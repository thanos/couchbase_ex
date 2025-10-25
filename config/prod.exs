import Config

# Production configuration
# In production, these should be set via environment variables
get_int_env = fn var, default ->
  case Integer.parse(System.get_env(var, default)) do
    {i, ""} -> i
    _ -> default
  end
end

config :couchbase_ex,
  connection_string: System.get_env("COUCHBASE_HOST"),
  username: System.get_env("COUCHBASE_USER"),
  password: System.get_env("COUCHBASE_PASSWORD"),
  bucket: System.get_env("COUCHBASE_BUCKET", "default"),
  timeout: get_int_env.("COUCHBASE_TIMEOUT", 5000),
  pool_size: get_int_env.("COUCHBASE_POOL_SIZE", 20),
  connection_timeout: get_int_env.("COUCHBASE_CONNECTION_TIMEOUT", 15000),
  query_timeout: get_int_env.("COUCHBASE_QUERY_TIMEOUT", 60000),
  operation_timeout: get_int_env.("COUCHBASE_OPERATION_TIMEOUT", 10000)

# Production logging
config :logger, level: :info

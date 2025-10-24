import Config

# Couchbase connection configuration
# These can be overridden by environment variables
config :couchbase_ex,
  connection_string: System.get_env("COUCHBASE_HOST", "couchbase://localhost"),
  username: System.get_env("COUCHBASE_USER", "Administrator"),
  password: System.get_env("COUCHBASE_PASSWORD", "password"),
  bucket: System.get_env("COUCHBASE_BUCKET", "default"),
  timeout: System.get_env("COUCHBASE_TIMEOUT", "5000") |> String.to_integer(),
  pool_size: System.get_env("COUCHBASE_POOL_SIZE", "10") |> String.to_integer(),
  connection_timeout:
    System.get_env("COUCHBASE_CONNECTION_TIMEOUT", "10000") |> String.to_integer(),
  query_timeout: System.get_env("COUCHBASE_QUERY_TIMEOUT", "30000") |> String.to_integer(),
  operation_timeout: System.get_env("COUCHBASE_OPERATION_TIMEOUT", "5000") |> String.to_integer()

# Zig server configuration
config :couchbase_ex,
  zig_server: [
    executable_path: System.get_env("COUCHBASE_ZIG_SERVER_PATH"),
    build_on_startup: System.get_env("COUCHBASE_BUILD_ZIG_SERVER", "false") == "true"
  ]

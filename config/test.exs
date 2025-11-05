import Config

# Test configuration
# These can be overridden by environment variables
# Use COUCHBASE_TEST_* variables for test-specific credentials
config :couchbase_ex,
  connection_string: System.get_env("COUCHBASE_TEST_HOST") || System.get_env("COUCHBASE_HOST", "http://127.0.0.1:8091/"),
  username: System.get_env("COUCHBASE_TEST_USER") || System.get_env("COUCHBASE_USER", "Administrator"),
  password: System.get_env("COUCHBASE_TEST_PASSWORD") || System.get_env("COUCHBASE_PASSWORD", "password"),
  bucket: System.get_env("COUCHBASE_TEST_BUCKET") || System.get_env("COUCHBASE_BUCKET", "default"),
  timeout: System.get_env("COUCHBASE_TIMEOUT", "2000") |> String.to_integer(),
  pool_size: System.get_env("COUCHBASE_POOL_SIZE", "2") |> String.to_integer(),
  connection_timeout: System.get_env("COUCHBASE_CONNECTION_TIMEOUT", "5000") |> String.to_integer(),
  query_timeout: System.get_env("COUCHBASE_QUERY_TIMEOUT", "10000") |> String.to_integer(),
  operation_timeout: System.get_env("COUCHBASE_OPERATION_TIMEOUT", "2000") |> String.to_integer()

# Zig server configuration for tests
config :couchbase_ex,
  zig_server: [
    executable_path: System.get_env("COUCHBASE_ZIG_SERVER_PATH", "priv/bin/couchbase_zig_server"),
    build_on_startup: System.get_env("COUCHBASE_BUILD_ZIG_SERVER_ON_STARTUP", "false") |> String.to_existing_atom()
  ]

# Test-specific logging
config :logger, level: :warning

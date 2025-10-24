import Config

# Test configuration
config :couchbase_ex,
  connection_string: System.get_env("COUCHBASE_HOST", "couchbase://127.0.0.1"),
  username: System.get_env("COUCHBASE_USER", "tester"),
  password: System.get_env("COUCHBASE_PASSWORD", "password"),
  bucket: System.get_env("COUCHBASE_BUCKET", "default"),
  timeout: 2000,
  pool_size: 2,
  connection_timeout: 5000,
  query_timeout: 10000,
  operation_timeout: 2000

# Zig server configuration for tests
config :couchbase_ex,
  zig_server: [
    # Will be determined at runtime
    executable_path: nil,
    build_on_startup: false
  ]

# Test-specific logging
config :logger, level: :warning

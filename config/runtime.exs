import Config

get_int_env = fn var, default ->
  case Integer.parse(System.get_env(var, default)) do
    {i, ""} -> i
    _ -> default
  end
end

get_bool_env = fn var, default ->
  case System.get_env(var, to_string(default)) do
    "true" -> true
    "false" -> false
    _ -> default
  end
end

# Couchbase connection configuration
# These can be overridden by environment variables
config :couchbase_ex,
  connection_string: System.get_env("COUCHBASE_HOST", "couchbase://localhost"),
  username: System.get_env("COUCHBASE_USER", "Administrator"),
  password: System.get_env("COUCHBASE_PASSWORD", "password"),
  bucket: System.get_env("COUCHBASE_BUCKET", "default"),
  timeout: get_int_env.("COUCHBASE_TIMEOUT", 5000),
  pool_size: get_int_env.("COUCHBASE_POOL_SIZE", 20),
  connection_timeout: get_int_env.("COUCHBASE_CONNECTION_TIMEOUT", 15000),
  query_timeout: get_int_env.("COUCHBASE_QUERY_TIMEOUT", 60000),
  operation_timeout: get_int_env.("COUCHBASE_OPERATION_TIMEOUT", 10000)

# Zig server configuration
config :couchbase_ex,
  zig_server: [
    executable_path: System.get_env("COUCHBASE_ZIG_SERVER_PATH"),
    build_on_startup: System.get_env("COUCHBASE_BUILD_ZIG_SERVER", "false") == "true"
  ]

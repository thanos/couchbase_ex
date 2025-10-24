import Config

# General application configuration
config :couchbase_ex,
  default_bucket: "default",
  default_timeout: 5000,
  default_pool_size: 10,
  default_connection_timeout: 10000,
  default_query_timeout: 30000,
  default_operation_timeout: 5000

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

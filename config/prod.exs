import Config

# Production configuration
# In production, these should be set via environment variables
get_int_env = fn var, default ->
  case Integer.parse(System.get_env(var, default)) do
    {i, ""} -> i
    _ -> default
  end
end

# Production logging
config :logger, level: :info

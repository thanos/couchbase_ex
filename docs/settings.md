# Settings & Configuration

CouchbaseEx provides flexible configuration options through multiple methods. This guide covers all available settings and how to configure them.

## Configuration Methods

CouchbaseEx supports configuration through:

1. **Environment Variables** - Runtime configuration
2. **`.env` Files** - Local development configuration
3. **Elixir Config** - Application configuration
4. **Programmatic** - Direct parameter passing

## Environment Variables

Set these environment variables to configure CouchbaseEx:

### Connection Settings

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `COUCHBASE_HOST` | Couchbase connection string | `couchbase://localhost` | `couchbase://192.168.1.100` |
| `COUCHBASE_USER` | Username for authentication | `Administrator` | `myuser` |
| `COUCHBASE_PASSWORD` | Password for authentication | `password` | `mypassword` |
| `COUCHBASE_BUCKET` | Default bucket name | `default` | `my_bucket` |

### Timeout Settings

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `COUCHBASE_TIMEOUT` | Default operation timeout (ms) | `5000` | `10000` |
| `COUCHBASE_CONNECTION_TIMEOUT` | Connection establishment timeout (ms) | `10000` | `15000` |
| `COUCHBASE_QUERY_TIMEOUT` | N1QL query timeout (ms) | `30000` | `60000` |
| `COUCHBASE_OPERATION_TIMEOUT` | Individual operation timeout (ms) | `5000` | `10000` |

### Pool Settings

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `COUCHBASE_POOL_SIZE` | Connection pool size | `10` | `20` |

### Zig Server Settings

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `COUCHBASE_ZIG_SERVER_PATH` | Path to Zig server executable | `priv/bin/couchbase_zig_server` | `/usr/local/bin/couchbase_zig_server` |
| `COUCHBASE_BUILD_ZIG_SERVER_ON_STARTUP` | Build Zig server on startup | `false` | `true` |

## .env Files

Create a `.env` file in your project root for local development:

```bash
# Copy the example file
cp env.example .env

# Edit with your values
COUCHBASE_HOST=couchbase://localhost
COUCHBASE_USER=Administrator
COUCHBASE_PASSWORD=password
COUCHBASE_BUCKET=default
COUCHBASE_TIMEOUT=5000
COUCHBASE_CONNECTION_TIMEOUT=10000
COUCHBASE_QUERY_TIMEOUT=30000
COUCHBASE_OPERATION_TIMEOUT=5000
COUCHBASE_POOL_SIZE=10
COUCHBASE_ZIG_SERVER_PATH=priv/bin/couchbase_zig_server
COUCHBASE_BUILD_ZIG_SERVER_ON_STARTUP=false
```

### Environment-Specific Files

CouchbaseEx automatically loads `.env` files in this order:

1. `.env` - Base configuration
2. `.env.{environment}` - Environment-specific (e.g., `.env.dev`, `.env.test`, `.env.prod`)
3. `.env.{environment}.local` - Local overrides (typically gitignored)

Example structure:
```
.env
.env.dev
.env.test
.env.prod
.env.dev.local
.env.prod.local
```

## Elixir Configuration

Configure CouchbaseEx in your Elixir config files:

### config/config.exs

```elixir
import Config

# General application configuration
config :couchbase_ex,
  default_bucket: "default",
  default_timeout: 5000,
  default_pool_size: 10
```

### config/runtime.exs

```elixir
import Config

# Runtime configuration with environment variables
config :couchbase_ex,
  connection_string: System.get_env("COUCHBASE_HOST", "couchbase://localhost"),
  username: System.get_env("COUCHBASE_USER", "Administrator"),
  password: System.get_env("COUCHBASE_PASSWORD", "password"),
  bucket: System.get_env("COUCHBASE_BUCKET", "default"),
  timeout: System.get_env("COUCHBASE_TIMEOUT", "5000") |> String.to_integer(),
  pool_size: System.get_env("COUCHBASE_POOL_SIZE", "10") |> String.to_integer()
```

### Environment-Specific Configs

#### config/dev.exs

```elixir
import Config

# Development configuration
config :couchbase_ex,
  connection_string: "couchbase://localhost",
  username: "Administrator",
  password: "password",
  bucket: "dev_bucket",
  timeout: 5000,
  pool_size: 5

# Enable debug logging
config :logger, level: :debug
```

#### config/test.exs

```elixir
import Config

# Test configuration
config :couchbase_ex,
  connection_string: "couchbase://127.0.0.1",
  username: "tester",
  password: "password",
  bucket: "test_bucket",
  timeout: 2000,
  pool_size: 2

# Test-specific logging
config :logger, level: :warning
```

#### config/prod.exs

```elixir
import Config

# Production configuration
config :couchbase_ex,
  connection_string: System.get_env("COUCHBASE_HOST"),
  username: System.get_env("COUCHBASE_USER"),
  password: System.get_env("COUCHBASE_PASSWORD"),
  bucket: System.get_env("COUCHBASE_BUCKET"),
  timeout: System.get_env("COUCHBASE_TIMEOUT", "5000") |> String.to_integer(),
  pool_size: System.get_env("COUCHBASE_POOL_SIZE", "20") |> String.to_integer()

# Production logging
config :logger, level: :info
```

## Programmatic Configuration

Override configuration at runtime:

```elixir
# Connect with custom settings
{:ok, client} = CouchbaseEx.connect(
  "couchbase://my-cluster.com",
  "myuser",
  "mypassword",
  bucket: "production",
  timeout: 10000,
  pool_size: 20
)

# Use custom options for operations
{:ok, result} = CouchbaseEx.get(client, "key", timeout: 5000)
```

## Configuration Precedence

Configuration is applied in this order (later overrides earlier):

1. **Default values** - Built-in defaults
2. **Elixir config** - Application configuration
3. **Environment variables** - Runtime overrides
4. **Programmatic** - Direct parameter passing

## Validation

CouchbaseEx validates all configuration options:

```elixir
# Invalid configuration will return an error
{:error, error} = CouchbaseEx.connect("invalid://url", "", "")

# Check error details
case error do
  %CouchbaseEx.Error{reason: :invalid_connection_params, message: msg} ->
    IO.puts("Invalid connection: #{msg}")
end
```

## Best Practices

### Development
- Use `.env` files for local development
- Keep sensitive data in `.env.local` (gitignored)
- Use descriptive bucket names per environment

### Testing
- Use separate test buckets
- Set shorter timeouts for faster test execution
- Use minimal pool sizes

### Production
- Use environment variables for all sensitive data
- Set appropriate timeouts based on your network
- Monitor connection pool usage
- Use connection string with multiple nodes for high availability

## Troubleshooting

### Common Issues

**Connection Timeout**
```elixir
# Increase connection timeout
config :couchbase_ex,
  connection_timeout: 30000  # 30 seconds
```

**Pool Exhaustion**
```elixir
# Increase pool size
config :couchbase_ex,
  pool_size: 50
```

**Invalid Configuration**
```elixir
# Check configuration
CouchbaseEx.Config.connection_string()
CouchbaseEx.Config.bucket()
```

### Debug Mode

Enable debug logging to troubleshoot connection issues:

```elixir
# In config/dev.exs
config :logger, level: :debug
```

This will show detailed connection and communication logs.

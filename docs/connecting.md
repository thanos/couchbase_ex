# Connecting to Couchbase

This guide covers everything you need to know about connecting to Couchbase using CouchbaseEx, including connection management, error handling, and best practices.

## Basic Connection

### Using Default Configuration

Connect using the default configuration from your application config:

```elixir
{:ok, client} = CouchbaseEx.connect()
```

### Using Explicit Parameters

Connect with explicit connection parameters:

```elixir
{:ok, client} = CouchbaseEx.connect(
  "couchbase://localhost",
  "Administrator",
  "password"
)
```

### Using Options

Connect with additional options:

```elixir
{:ok, client} = CouchbaseEx.connect(
  "couchbase://localhost",
  "Administrator",
  "password",
  bucket: "my_bucket",
  timeout: 10000,
  pool_size: 20
)
```

## Connection Strings

CouchbaseEx supports various connection string formats:

### Single Node

```elixir
"couchbase://localhost"
"couchbase://192.168.1.100"
"couchbase://couchbase.example.com"
```

### Multiple Nodes (High Availability)

```elixir
"couchbase://node1.example.com,node2.example.com,node3.example.com"
```

### With Port

```elixir
"couchbase://localhost:8091"
"couchbase://192.168.1.100:8091"
```

### With SSL

```elixir
"couchbases://secure.example.com"  # Note: couchbases:// for SSL
```

## Connection Options

All connection options are validated using nimble_options:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `bucket` | `String.t()` | `"default"` | Couchbase bucket name |
| `timeout` | `non_neg_integer()` | `5000` | Default operation timeout (ms) |
| `expiry` | `non_neg_integer() \| nil` | `nil` | Document expiry time (seconds) |
| `durability` | `atom()` | `:none` | Durability level for write operations |
| `params` | `list()` | `[]` | Parameters for parameterized queries |
| `pool_size` | `non_neg_integer()` | `10` | Connection pool size |
| `connection_timeout` | `non_neg_integer()` | `10000` | Connection establishment timeout (ms) |
| `query_timeout` | `non_neg_integer()` | `30000` | N1QL query timeout (ms) |
| `operation_timeout` | `non_neg_integer()` | `5000` | Individual operation timeout (ms) |

### Durability Levels

```elixir
# Available durability levels
:none                           # No durability requirements
:majority                       # Majority of nodes must acknowledge
:majority_and_persist          # Majority + persist to disk
:persist_to_majority           # Persist to majority of nodes
```

## Error Handling

### Connection Errors

Handle different types of connection errors:

```elixir
case CouchbaseEx.connect("couchbase://localhost", "user", "pass") do
  {:ok, client} ->
    IO.puts("Connected successfully!")
    
  {:error, %CouchbaseEx.Error{reason: :invalid_connection_params}} ->
    IO.puts("Invalid connection parameters")
    
  {:error, %CouchbaseEx.Error{reason: :connection_failed}} ->
    IO.puts("Failed to connect to Couchbase server")
    
  {:error, %CouchbaseEx.Error{reason: :invalid_options}} ->
    IO.puts("Invalid connection options provided")
    
  {:error, error} ->
    IO.puts("Unexpected error: #{inspect(error)}")
end
```

### Validation Errors

CouchbaseEx validates connection parameters before attempting to connect:

```elixir
# These will return {:error, %Error{reason: :invalid_connection_params}}
CouchbaseEx.connect("", "user", "pass")           # Empty connection string
CouchbaseEx.connect("couchbase://localhost", "", "pass")  # Empty username
CouchbaseEx.connect("couchbase://localhost", "user", "")  # Empty password
CouchbaseEx.connect("invalid://url", "user", "pass")      # Invalid protocol
```

## Connection Management

### Closing Connections

Always close connections when done:

```elixir
# Close a single connection
CouchbaseEx.close(client)
```

### Connection Lifecycle

```elixir
# Complete connection lifecycle
defmodule MyApp.CouchbaseService do
  def with_connection(fun) do
    case CouchbaseEx.connect() do
      {:ok, client} ->
        try do
          fun.(client)
        after
          CouchbaseEx.close(client)
        end
        
      {:error, error} ->
        {:error, error}
    end
  end
end

# Usage
{:ok, result} = MyApp.CouchbaseService.with_connection(fn client ->
  CouchbaseEx.get(client, "my_key")
end)
```

### Connection Pooling

CouchbaseEx manages connection pooling automatically:

```elixir
# Configure pool size
{:ok, client} = CouchbaseEx.connect(
  "couchbase://localhost",
  "Administrator",
  "password",
  pool_size: 20  # Allow up to 20 concurrent connections
)
```

## Health Checks

### Ping the Cluster

Check if the cluster is responding:

```elixir
case CouchbaseEx.ping(client) do
  {:ok, ping_result} ->
    IO.puts("Cluster is healthy: #{inspect(ping_result)}")
    
  {:error, error} ->
    IO.puts("Cluster health check failed: #{inspect(error)}")
end
```

### Get Diagnostics

Get detailed cluster diagnostics:

```elixir
case CouchbaseEx.diagnostics(client) do
  {:ok, diagnostics} ->
    IO.puts("Cluster diagnostics: #{inspect(diagnostics)}")
    
  {:error, error} ->
    IO.puts("Failed to get diagnostics: #{inspect(error)}")
end
```

## Advanced Connection Scenarios

### Multiple Environments

```elixir
defmodule MyApp.Couchbase do
  def connect_for_env(env) do
    case env do
      :dev -> CouchbaseEx.connect("couchbase://localhost", "dev_user", "dev_pass")
      :test -> CouchbaseEx.connect("couchbase://127.0.0.1", "test_user", "test_pass")
      :prod -> CouchbaseEx.connect(System.get_env("COUCHBASE_HOST"), 
                                  System.get_env("COUCHBASE_USER"), 
                                  System.get_env("COUCHBASE_PASSWORD"))
    end
  end
end
```

### Connection with Retry

```elixir
defmodule MyApp.CouchbaseRetry do
  def connect_with_retry(connection_string, username, password, opts \\ [], retries \\ 3) do
    case CouchbaseEx.connect(connection_string, username, password, opts) do
      {:ok, client} -> {:ok, client}
      {:error, _} when retries > 0 ->
        Process.sleep(1000)  # Wait 1 second
        connect_with_retry(connection_string, username, password, opts, retries - 1)
      {:error, error} -> {:error, error}
    end
  end
end
```

### Connection Monitoring

```elixir
defmodule MyApp.CouchbaseMonitor do
  use GenServer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(opts) do
    schedule_health_check()
    {:ok, %{client: nil, opts: opts}}
  end
  
  def handle_info(:health_check, state) do
    case ensure_connected(state) do
      {:ok, new_state} ->
        schedule_health_check()
        {:noreply, new_state}
      {:error, error} ->
        IO.puts("Connection lost: #{inspect(error)}")
        schedule_health_check()
        {:noreply, %{state | client: nil}}
    end
  end
  
  defp ensure_connected(%{client: nil} = state) do
    case CouchbaseEx.connect(state.opts) do
      {:ok, client} -> {:ok, %{state | client: client}}
      {:error, error} -> {:error, error}
    end
  end
  
  defp ensure_connected(%{client: client} = state) do
    case CouchbaseEx.ping(client) do
      {:ok, _} -> {:ok, state}
      {:error, _} -> ensure_connected(%{state | client: nil})
    end
  end
  
  defp schedule_health_check do
    Process.send_after(self(), :health_check, 30_000)  # Check every 30 seconds
  end
end
```

## Best Practices

### Connection Management

1. **Always close connections** when done
2. **Use connection pooling** for high-throughput applications
3. **Monitor connection health** in production
4. **Handle connection failures** gracefully

### Security

1. **Use environment variables** for sensitive data
2. **Use SSL connections** in production
3. **Rotate credentials** regularly
4. **Use least-privilege** user accounts

### Performance

1. **Tune pool size** based on your workload
2. **Set appropriate timeouts** for your network
3. **Use connection string with multiple nodes** for high availability
4. **Monitor connection metrics**

### Error Handling

1. **Always handle connection errors**
2. **Implement retry logic** for transient failures
3. **Log connection issues** for debugging
4. **Gracefully degrade** when Couchbase is unavailable

## Troubleshooting

### Common Connection Issues

**Connection Timeout**
```elixir
# Increase connection timeout
{:ok, client} = CouchbaseEx.connect(
  "couchbase://localhost",
  "user",
  "pass",
  connection_timeout: 30000  # 30 seconds
)
```

**Authentication Failed**
```elixir
# Check credentials
IO.puts("Username: #{System.get_env("COUCHBASE_USER")}")
IO.puts("Password: #{String.length(System.get_env("COUCHBASE_PASSWORD", ""))} chars")
```

**Network Issues**
```elixir
# Test network connectivity
:net_adm.ping(:"couchbase@localhost")
```

**Pool Exhaustion**
```elixir
# Increase pool size
{:ok, client} = CouchbaseEx.connect(
  "couchbase://localhost",
  "user",
  "pass",
  pool_size: 50
)
```

### Debug Mode

Enable debug logging to troubleshoot connection issues:

```elixir
# In config/dev.exs
config :logger, level: :debug
```

This will show detailed connection and communication logs.

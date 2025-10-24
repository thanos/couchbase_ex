# CouchbaseEx

[![Hex.pm](https://img.shields.io/hexpm/v/couchbase_ex.svg)](https://hex.pm/packages/couchbase_ex)
[![Hex.pm](https://img.shields.io/hexpm/dt/couchbase_ex.svg)](https://hex.pm/packages/couchbase_ex)
[![Hex.pm](https://img.shields.io/hexpm/dw/couchbase_ex.svg)](https://hex.pm/packages/couchbase_ex)

An Elixir client for Couchbase Server using a Zig port for high-performance operations.

## Features

- **High Performance**: Uses Zig port for maximum performance
- **Full CRUD Operations**: Get, set, upsert, delete, insert, replace
- **Subdocument Operations**: Efficient subdocument lookups and mutations
- **N1QL Query Support**: Execute N1QL queries with parameter binding
- **Connection Management**: Automatic connection pooling and management
- **Error Handling**: Comprehensive error handling with retry logic
- **Timeout Management**: Configurable timeouts for all operations
- **Comprehensive Testing**: Full test suite with integration tests

## Installation

Add `couchbase_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:couchbase_ex, "~> 0.1.0"}
  ]
end
```

## Quick Start

```elixir
# Connect to Couchbase using configuration
{:ok, client} = CouchbaseEx.connect()

# Basic operations
CouchbaseEx.set(client, "user:123", %{name: "John", age: 30})
{:ok, document} = CouchbaseEx.get(client, "user:123")

# N1QL queries
{:ok, results} = CouchbaseEx.query(client, "SELECT * FROM `default` WHERE age > 25")

# Clean up
CouchbaseEx.close(client)
```

## Configuration

### Environment Variables

You can configure the client using environment variables:

```bash
export COUCHBASE_HOST="couchbase://localhost"
export COUCHBASE_USER="Administrator"
export COUCHBASE_PASSWORD="password"
export COUCHBASE_BUCKET="default"
export COUCHBASE_TIMEOUT="5000"
export COUCHBASE_POOL_SIZE="10"
```

### Configuration Files

The client uses Elixir's standard configuration system:

**config/runtime.exs** (recommended for production):
```elixir
import Config

config :couchbase_ex,
  connection_string: System.get_env("COUCHBASE_HOST", "couchbase://localhost"),
  username: System.get_env("COUCHBASE_USER", "Administrator"),
  password: System.get_env("COUCHBASE_PASSWORD", "password"),
  bucket: System.get_env("COUCHBASE_BUCKET", "default"),
  timeout: System.get_env("COUCHBASE_TIMEOUT", "5000") |> String.to_integer(),
  pool_size: System.get_env("COUCHBASE_POOL_SIZE", "10") |> String.to_integer()
```

**config/dev.exs** (for development):
```elixir
import Config

config :couchbase_ex,
  connection_string: "couchbase://localhost",
  username: "Administrator",
  password: "password",
  bucket: "default",
  timeout: 5000,
  pool_size: 5
```

### Programmatic Configuration

```elixir
# Using configuration
{:ok, client} = CouchbaseEx.connect()

# With explicit parameters
{:ok, client} = CouchbaseEx.connect("couchbase://localhost", "admin", "password", [
  bucket: "my_bucket",
  timeout: 10000,
  pool_size: 20
])

# With options override
{:ok, client} = CouchbaseEx.connect(bucket: "my_bucket", timeout: 10000)
```

## API Reference

### Connection Management

#### `CouchbaseEx.connect/0` and `CouchbaseEx.connect/1`

Connects to a Couchbase cluster using configuration.

```elixir
# Using configuration
{:ok, client} = CouchbaseEx.connect()

# With options override
{:ok, client} = CouchbaseEx.connect(bucket: "my_bucket", timeout: 10000)
```

#### `CouchbaseEx.connect/3` and `CouchbaseEx.connect/4`

Connects to a Couchbase cluster with explicit parameters.

```elixir
# Basic connection
{:ok, client} = CouchbaseEx.connect("couchbase://localhost", "admin", "password")

# Connection with options
{:ok, client} = CouchbaseEx.connect("couchbase://localhost", "admin", "password", [
  bucket: "my_bucket",
  timeout: 10000,
  pool_size: 20
])
```

#### `CouchbaseEx.close/1`

Closes the connection to Couchbase.

```elixir
CouchbaseEx.close(client)
```

### CRUD Operations

#### `CouchbaseEx.get/2` and `CouchbaseEx.get/3`

Gets a document by key.

```elixir
{:ok, document} = CouchbaseEx.get(client, "user:123")
{:ok, document} = CouchbaseEx.get(client, "user:123", timeout: 5000)
```

#### `CouchbaseEx.set/3` and `CouchbaseEx.set/4`

Sets a document (insert or update).

```elixir
CouchbaseEx.set(client, "user:123", %{name: "John", age: 30})
CouchbaseEx.set(client, "user:123", %{name: "John"}, expiry: 3600)
```

#### `CouchbaseEx.insert/3` and `CouchbaseEx.insert/4`

Inserts a new document (fails if document exists).

```elixir
CouchbaseEx.insert(client, "user:123", %{name: "John"})
```

#### `CouchbaseEx.replace/3` and `CouchbaseEx.replace/4`

Replaces an existing document (fails if document doesn't exist).

```elixir
CouchbaseEx.replace(client, "user:123", %{name: "John Updated"})
```

#### `CouchbaseEx.upsert/3` and `CouchbaseEx.upsert/4`

Upserts a document (insert or update).

```elixir
CouchbaseEx.upsert(client, "user:123", %{name: "John"})
```

#### `CouchbaseEx.delete/2` and `CouchbaseEx.delete/3`

Deletes a document by key.

```elixir
CouchbaseEx.delete(client, "user:123")
```

#### `CouchbaseEx.exists/2` and `CouchbaseEx.exists/3`

Checks if a document exists.

```elixir
{:ok, exists} = CouchbaseEx.exists(client, "user:123")
```

### N1QL Queries

#### `CouchbaseEx.query/2` and `CouchbaseEx.query/3`

Executes a N1QL query.

```elixir
# Simple query
{:ok, results} = CouchbaseEx.query(client, "SELECT * FROM `default`")

# Query with parameters
{:ok, results} = CouchbaseEx.query(client, "SELECT * FROM `default` WHERE name = $1", 
  params: ["John"])

# Query with timeout
{:ok, results} = CouchbaseEx.query(client, "SELECT * FROM `default`", timeout: 30000)
```

### Subdocument Operations

#### `CouchbaseEx.lookup_in/3` and `CouchbaseEx.lookup_in/4`

Performs subdocument lookup operations.

```elixir
specs = [
  %{op: "get", path: "name"},
  %{op: "get", path: "age"},
  %{op: "exists", path: "email"}
]

{:ok, results} = CouchbaseEx.lookup_in(client, "user:123", specs)
```

#### `CouchbaseEx.mutate_in/3` and `CouchbaseEx.mutate_in/4`

Performs subdocument mutation operations.

```elixir
specs = [
  %{op: "upsert", path: "name", value: "John Updated"},
  %{op: "increment", path: "age", value: 1},
  %{op: "remove", path: "old_field"}
]

CouchbaseEx.mutate_in(client, "user:123", specs)
```

### Health and Diagnostics

#### `CouchbaseEx.ping/1` and `CouchbaseEx.ping/2`

Pings the Couchbase cluster.

```elixir
{:ok, ping_result} = CouchbaseEx.ping(client)
```

#### `CouchbaseEx.diagnostics/1` and `CouchbaseEx.diagnostics/2`

Gets cluster diagnostics.

```elixir
{:ok, diagnostics} = CouchbaseEx.diagnostics(client)
```

## Error Handling

CouchbaseEx provides comprehensive error handling with retry logic:

```elixir
case CouchbaseEx.get(client, "user:123") do
  {:ok, document} ->
    # Handle success
    IO.puts("Document: #{inspect(document)}")
    
  {:error, %CouchbaseEx.Error{reason: :document_not_found}} ->
    # Handle specific error
    IO.puts("Document not found")
    
  {:error, %CouchbaseEx.Error{reason: :timeout}} ->
    # Handle timeout with retry
    Process.sleep(1000)
    CouchbaseEx.get(client, "user:123")
    
  {:error, error} ->
    # Handle other errors
    IO.puts("Error: #{error.message}")
end
```

### Error Types

- `:document_not_found` - Document doesn't exist
- `:document_exists` - Document already exists
- `:document_locked` - Document is locked
- `:timeout` - Operation timed out
- `:authentication_failed` - Authentication failed
- `:bucket_not_found` - Bucket doesn't exist
- `:temporary_failure` - Temporary failure (retryable)
- `:durability_ambiguous` - Durability level ambiguous
- `:invalid_argument` - Invalid argument provided
- `:connection_failed` - Connection to cluster failed
- `:communication_failed` - Communication with Zig port failed

### Retry Logic

```elixir
def retry_operation(client, key, max_attempts \\ 3) do
  case CouchbaseEx.get(client, key) do
    {:ok, document} -> {:ok, document}
    {:error, %CouchbaseEx.Error{} = error} ->
      if CouchbaseEx.Error.retryable?(error) and max_attempts > 0 do
        delay = CouchbaseEx.Error.retry_delay(error, 4 - max_attempts)
        Process.sleep(delay)
        retry_operation(client, key, max_attempts - 1)
      else
        {:error, error}
      end
  end
end
```

## Configuration Options

### Connection Options

- `bucket` - Bucket name (default: "default")
- `timeout` - Operation timeout in milliseconds (default: 5000)
- `pool_size` - Connection pool size (default: 10)
- `connection_timeout` - Connection timeout in milliseconds (default: 10000)

### Operation Options

- `expiry` - Document expiry in seconds
- `durability` - Durability level (`:none`, `:majority`, `:majority_and_persist`, `:persist_to_majority`)
- `timeout` - Operation timeout in milliseconds

### Query Options

- `params` - Query parameters
- `timeout` - Query timeout in milliseconds (default: 30000)

## Testing

### Unit Tests

```bash
mix test
```

### Integration Tests

Integration tests require a running Couchbase Server instance:

```bash
# Start Couchbase Server with Docker
docker run -d --name couchbase \
  -p 8091-8096:8091-8096 \
  -p 11210-11211:11210-11211 \
  couchbase:community

# Configure Couchbase
export COUCHBASE_HOST="couchbase://127.0.0.1"
export COUCHBASE_USER="Administrator"
export COUCHBASE_PASSWORD="password"
export COUCHBASE_BUCKET="default"

# Run integration tests
mix test --only integration
```

### Test Configuration

The test suite uses environment variables for configuration:

- `COUCHBASE_HOST` - Couchbase connection string
- `COUCHBASE_USER` - Username
- `COUCHBASE_PASSWORD` - Password
- `COUCHBASE_BUCKET` - Bucket name

## Performance

CouchbaseEx is designed for high performance:

- **Zig Port**: Uses a Zig server for maximum performance
- **Connection Pooling**: Automatic connection management
- **Efficient Serialization**: Optimized JSON serialization
- **Memory Management**: Proper resource cleanup

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Elixir App    │    │  CouchbaseEx   │    │   Zig Server    │
│                 │    │                │    │                 │
│  CouchbaseEx.   │───▶│  Port Manager  │───▶│  couchbase-zig  │
│  get/set/query  │    │                │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
                        ┌─────────────────┐
                        │  Couchbase      │
                        │  Server         │
                        └─────────────────┘
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Run the test suite
6. Submit a pull request

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Links

- [Hex.pm Package](https://hex.pm/packages/couchbase_ex)
- [Couchbase Documentation](https://docs.couchbase.com/)
- [Zig Documentation](https://ziglang.org/documentation/)
- [Elixir Documentation](https://elixir-lang.org/docs.html)
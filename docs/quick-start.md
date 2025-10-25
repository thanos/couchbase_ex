# Quick Start Guide

Get up and running with CouchbaseEx in minutes! This guide will walk you through the essential steps to start using CouchbaseEx in your Elixir application.

## Installation

Add CouchbaseEx to your dependencies in `mix.exs`:

```elixir
defp deps do
  [
    {:couchbase_ex, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Configuration

Configure CouchbaseEx in your `config/config.exs`:

```elixir
import Config

config :couchbase_ex,
  connection_string: "couchbase://localhost",
  username: "Administrator",
  password: "password",
  bucket: "default",
  timeout: 5000
```

> **💡 Pro Tip:** You can also use environment variables or .env files for configuration. See the [Settings](settings.html) page for more details.

## Basic Connection

Connect to Couchbase using the default configuration:

```elixir
# Using default configuration
{:ok, client} = CouchbaseEx.connect()

# Or with explicit parameters
{:ok, client} = CouchbaseEx.connect(
  "couchbase://localhost",
  "Administrator", 
  "password",
  bucket: "my_bucket"
)
```

## Basic CRUD Operations

### Create/Update Documents

```elixir
# Set a document
{:ok, _} = CouchbaseEx.set(client, "user:123", %{
  name: "John Doe",
  email: "john@example.com",
  age: 30
})

# Insert a new document (fails if exists)
{:ok, _} = CouchbaseEx.insert(client, "user:456", %{
  name: "Jane Smith",
  email: "jane@example.com"
})

# Upsert a document (insert or update)
{:ok, _} = CouchbaseEx.upsert(client, "user:789", %{
  name: "Bob Wilson",
  email: "bob@example.com"
})
```

### Read Documents

```elixir
# Get a document
{:ok, user} = CouchbaseEx.get(client, "user:123")
IO.inspect(user)
# => %{"name" => "John Doe", "email" => "john@example.com", "age" => 30}

# Check if document exists
{:ok, exists} = CouchbaseEx.exists(client, "user:123")
# => true
```

### Delete Documents

```elixir
# Delete a document
{:ok, _} = CouchbaseEx.delete(client, "user:123")

# Replace an existing document
{:ok, _} = CouchbaseEx.replace(client, "user:456", %{
  name: "Jane Smith Updated",
  email: "jane.updated@example.com"
})
```

## Querying with N1QL

```elixir
# Simple query
{:ok, results} = CouchbaseEx.query(client, "SELECT * FROM `default` WHERE age > 25")

# Query with parameters
{:ok, results} = CouchbaseEx.query(client, 
  "SELECT * FROM `default` WHERE name = $1",
  params: ["John Doe"]
)
```

## Advanced Options

All operations support various options:

```elixir
# Set with options
{:ok, _} = CouchbaseEx.set(client, "user:123", %{name: "John"}, 
  timeout: 10000,
  expiry: 3600,  # Expires in 1 hour
  durability: :majority
)

# Get with custom timeout
{:ok, user} = CouchbaseEx.get(client, "user:123", timeout: 5000)
```

## Cleanup

Always close the connection when done:

```elixir
# Close the connection
CouchbaseEx.close(client)
```

## Error Handling

```elixir
case CouchbaseEx.get(client, "user:123") do
  {:ok, user} -> 
    IO.puts("User found: #{user["name"]}")
  {:error, %CouchbaseEx.Error{reason: :not_found}} -> 
    IO.puts("User not found")
  {:error, %CouchbaseEx.Error{reason: :not_connected}} -> 
    IO.puts("Not connected to Couchbase")
  {:error, error} -> 
    IO.puts("Error: #{inspect(error)}")
end
```

## Next Steps

- [Settings & Configuration](settings.html) - Learn about all configuration options
- [Connecting](connecting.html) - Detailed connection management guide
- [CRUD Operations](crud-operations.html) - Complete guide to data operations
- [API Reference](CouchbaseEx.html) - Full API documentation

> **🎉 Congratulations!** You've successfully set up CouchbaseEx and performed your first operations. You're ready to build amazing applications with Couchbase and Elixir!

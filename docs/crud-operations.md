# CRUD Operations

This comprehensive guide covers all Create, Read, Update, and Delete operations available in CouchbaseEx, including advanced features and best practices.

## Overview

CouchbaseEx provides a complete set of CRUD operations for working with Couchbase documents:

- **Create**: `insert/4` - Insert new documents
- **Read**: `get/3`, `exists/3` - Retrieve and check documents
- **Update**: `set/4`, `replace/4`, `upsert/4` - Modify documents
- **Delete**: `delete/3` - Remove documents

## Create Operations

### Insert

Insert a new document (fails if document already exists):

```elixir
# Basic insert
{:ok, result} = CouchbaseEx.insert(client, "user:123", %{
  name: "John Doe",
  email: "john@example.com",
  age: 30
})

# Insert with options
{:ok, result} = CouchbaseEx.insert(client, "user:456", %{
  name: "Jane Smith",
  email: "jane@example.com"
}, timeout: 10000, expiry: 3600, durability: :majority)
```

### Set

Set a document (insert or update):

```elixir
# Basic set
{:ok, result} = CouchbaseEx.set(client, "user:123", %{
  name: "John Doe",
  email: "john@example.com",
  age: 30
})

# Set with options
{:ok, result} = CouchbaseEx.set(client, "user:456", %{
  name: "Jane Smith",
  email: "jane@example.com"
}, timeout: 10000, expiry: 3600, durability: :majority)
```

### Upsert

Upsert a document (insert or update, always succeeds):

```elixir
# Basic upsert
{:ok, result} = CouchbaseEx.upsert(client, "user:789", %{
  name: "Bob Wilson",
  email: "bob@example.com",
  age: 25
})

# Upsert with options
{:ok, result} = CouchbaseEx.upsert(client, "user:101", %{
  name: "Alice Johnson",
  email: "alice@example.com"
}, timeout: 10000, expiry: 7200, durability: :majority_and_persist)
```

## Read Operations

### Get

Retrieve a document by key:

```elixir
# Basic get
{:ok, user} = CouchbaseEx.get(client, "user:123")
IO.inspect(user)
# => %{"name" => "John Doe", "email" => "john@example.com", "age" => 30}

# Get with timeout
{:ok, user} = CouchbaseEx.get(client, "user:123", timeout: 5000)

# Handle not found
case CouchbaseEx.get(client, "user:999") do
  {:ok, user} -> IO.puts("User found: #{user["name"]}")
  {:error, %CouchbaseEx.Error{reason: :not_found}} -> IO.puts("User not found")
  {:error, error} -> IO.puts("Error: #{inspect(error)}")
end
```

### Exists

Check if a document exists:

```elixir
# Check existence
{:ok, exists} = CouchbaseEx.exists(client, "user:123")
# => true

# Check with timeout
{:ok, exists} = CouchbaseEx.exists(client, "user:123", timeout: 5000)

# Use in conditional logic
case CouchbaseEx.exists(client, "user:123") do
  {:ok, true} -> IO.puts("User exists")
  {:ok, false} -> IO.puts("User does not exist")
  {:error, error} -> IO.puts("Error checking existence: #{inspect(error)}")
end
```

## Update Operations

### Replace

Replace an existing document (fails if document doesn't exist):

```elixir
# Basic replace
{:ok, result} = CouchbaseEx.replace(client, "user:123", %{
  name: "John Doe Updated",
  email: "john.updated@example.com",
  age: 31
})

# Replace with options
{:ok, result} = CouchbaseEx.replace(client, "user:456", %{
  name: "Jane Smith Updated",
  email: "jane.updated@example.com"
}, timeout: 10000, expiry: 1800, durability: :majority)
```

### Update with Set

Use `set/4` to update existing documents:

```elixir
# Update existing document
{:ok, result} = CouchbaseEx.set(client, "user:123", %{
  name: "John Doe",
  email: "john@example.com",
  age: 31,  # Updated age
  last_login: DateTime.utc_now()
})
```

## Delete Operations

### Delete

Remove a document by key:

```elixir
# Basic delete
{:ok, result} = CouchbaseEx.delete(client, "user:123")

# Delete with options
{:ok, result} = CouchbaseEx.delete(client, "user:456", 
  timeout: 5000, 
  durability: :majority
)

# Handle delete errors
case CouchbaseEx.delete(client, "user:999") do
  {:ok, _} -> IO.puts("User deleted successfully")
  {:error, %CouchbaseEx.Error{reason: :not_found}} -> IO.puts("User not found")
  {:error, error} -> IO.puts("Delete error: #{inspect(error)}")
end
```

## Advanced Operations

### Subdocument Operations

#### Lookup In

Retrieve specific fields from a document:

```elixir
# Get specific fields
specs = [
  %{op: "get", path: "name"},
  %{op: "get", path: "email"},
  %{op: "get", path: "profile.age"}
]

{:ok, results} = CouchbaseEx.lookup_in(client, "user:123", specs)
# => [%{"name" => "John Doe"}, %{"email" => "john@example.com"}, %{"age" => 30}]

# Get with timeout
{:ok, results} = CouchbaseEx.lookup_in(client, "user:123", specs, timeout: 5000)
```

#### Mutate In

Modify specific fields in a document:

```elixir
# Update specific fields
specs = [
  %{op: "upsert", path: "name", value: "John Doe Updated"},
  %{op: "upsert", path: "last_login", value: DateTime.utc_now()},
  %{op: "increment", path: "login_count", value: 1}
]

{:ok, results} = CouchbaseEx.mutate_in(client, "user:123", specs)

# Mutate with options
{:ok, results} = CouchbaseEx.mutate_in(client, "user:123", specs,
  timeout: 10000,
  expiry: 3600,
  durability: :majority
)
```

### Batch Operations

Process multiple documents efficiently:

```elixir
defmodule MyApp.BatchOperations do
  def batch_get(client, keys) do
    keys
    |> Enum.map(fn key ->
      Task.async(fn -> CouchbaseEx.get(client, key) end)
    end)
    |> Enum.map(&Task.await/1)
  end
  
  def batch_set(client, documents) do
    documents
    |> Enum.map(fn {key, value} ->
      Task.async(fn -> CouchbaseEx.set(client, key, value) end)
    end)
    |> Enum.map(&Task.await/1)
  end
end

# Usage
keys = ["user:1", "user:2", "user:3"]
results = MyApp.BatchOperations.batch_get(client, keys)

documents = [
  {"user:4", %{name: "User 4"}},
  {"user:5", %{name: "User 5"}},
  {"user:6", %{name: "User 6"}}
]
results = MyApp.BatchOperations.batch_set(client, documents)
```

## Options and Configuration

### Available Options

All CRUD operations support these options:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `timeout` | `non_neg_integer()` | `5000` | Operation timeout (ms) |
| `expiry` | `non_neg_integer() \| nil` | `nil` | Document expiry (seconds) |
| `durability` | `atom()` | `:none` | Durability level |
| `params` | `list()` | `[]` | Query parameters |

### Durability Levels

```elixir
# Available durability levels
:none                           # No durability requirements
:majority                       # Majority of nodes must acknowledge
:majority_and_persist          # Majority + persist to disk
:persist_to_majority           # Persist to majority of nodes

# Example with durability
{:ok, result} = CouchbaseEx.set(client, "important:doc", %{data: "critical"},
  durability: :majority_and_persist
)
```

### Expiry Settings

```elixir
# Document expires in 1 hour
{:ok, result} = CouchbaseEx.set(client, "temp:doc", %{data: "temporary"},
  expiry: 3600
)

# Document expires in 1 day
{:ok, result} = CouchbaseEx.set(client, "session:123", %{user_id: 123},
  expiry: 86400
)

# No expiry (default)
{:ok, result} = CouchbaseEx.set(client, "permanent:doc", %{data: "permanent"},
  expiry: nil
)
```

## Error Handling

### Common Error Types

```elixir
def handle_crud_error({:error, %CouchbaseEx.Error{reason: reason} = error}) do
  case reason do
    :not_found ->
      IO.puts("Document not found")
      
    :key_exists ->
      IO.puts("Document already exists (insert failed)")
      
    :not_connected ->
      IO.puts("Not connected to Couchbase")
      
    :timeout ->
      IO.puts("Operation timed out")
      
    :invalid_options ->
      IO.puts("Invalid options provided: #{error.message}")
      
    :communication_failed ->
      IO.puts("Communication with Couchbase failed")
      
    _ ->
      IO.puts("Unexpected error: #{inspect(error)}")
  end
end
```

### Retry Logic

```elixir
defmodule MyApp.CRUDRetry do
  def with_retry(operation, max_retries \\ 3) do
    case operation.() do
      {:ok, result} -> {:ok, result}
      {:error, %CouchbaseEx.Error{reason: :timeout}} when max_retries > 0 ->
        Process.sleep(1000)
        with_retry(operation, max_retries - 1)
      {:error, error} -> {:error, error}
    end
  end
end

# Usage
{:ok, user} = MyApp.CRUDRetry.with_retry(fn ->
  CouchbaseEx.get(client, "user:123")
end)
```

## Best Practices

### Document Design

1. **Use meaningful keys**: `user:123`, `order:456`, `session:abc123`
2. **Keep documents small**: Avoid very large documents
3. **Use consistent structure**: Similar documents should have similar fields
4. **Consider expiry**: Set appropriate TTL for temporary data

### Performance

1. **Use appropriate timeouts**: Set timeouts based on your network
2. **Batch operations**: Use batch processing for multiple documents
3. **Use subdocuments**: For large documents, use subdocument operations
4. **Monitor performance**: Track operation times and error rates

### Error Handling

1. **Always handle errors**: Don't ignore error responses
2. **Implement retry logic**: For transient failures
3. **Log errors**: For debugging and monitoring
4. **Graceful degradation**: Handle Couchbase unavailability

### Security

1. **Validate input**: Sanitize data before storing
2. **Use appropriate durability**: For critical data
3. **Set expiry**: For sensitive temporary data
4. **Monitor access**: Log and monitor document access

## Examples

### User Management System

```elixir
defmodule MyApp.UserService do
  def create_user(client, user_data) do
    user_id = generate_user_id()
    key = "user:#{user_id}"
    
    user = Map.merge(user_data, %{
      id: user_id,
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    })
    
    CouchbaseEx.insert(client, key, user, 
      expiry: nil,  # Permanent user
      durability: :majority
    )
  end
  
  def get_user(client, user_id) do
    CouchbaseEx.get(client, "user:#{user_id}")
  end
  
  def update_user(client, user_id, updates) do
    key = "user:#{user_id}"
    
    with {:ok, current_user} <- CouchbaseEx.get(client, key) do
      updated_user = Map.merge(current_user, updates, %{
        updated_at: DateTime.utc_now()
      })
      
      CouchbaseEx.replace(client, key, updated_user,
        durability: :majority
      )
    end
  end
  
  def delete_user(client, user_id) do
    CouchbaseEx.delete(client, "user:#{user_id}",
      durability: :majority
    )
  end
  
  defp generate_user_id do
    :crypto.strong_rand_bytes(8) |> Base.encode64(padding: false)
  end
end
```

### Session Management

```elixir
defmodule MyApp.SessionService do
  def create_session(client, user_id) do
    session_id = generate_session_id()
    key = "session:#{session_id}"
    
    session = %{
      user_id: user_id,
      created_at: DateTime.utc_now(),
      last_activity: DateTime.utc_now()
    }
    
    CouchbaseEx.set(client, key, session,
      expiry: 3600,  # 1 hour
      durability: :none  # Sessions can be recreated
    )
  end
  
  def get_session(client, session_id) do
    CouchbaseEx.get(client, "session:#{session_id}")
  end
  
  def update_activity(client, session_id) do
    key = "session:#{session_id}"
    
    with {:ok, session} <- CouchbaseEx.get(client, key) do
      updated_session = Map.put(session, "last_activity", DateTime.utc_now())
      
      CouchbaseEx.set(client, key, updated_session,
        expiry: 3600,  # Reset expiry
        durability: :none
      )
    end
  end
  
  defp generate_session_id do
    :crypto.strong_rand_bytes(32) |> Base.encode64(padding: false)
  end
end
```

This comprehensive guide covers all aspects of CRUD operations in CouchbaseEx, from basic usage to advanced patterns and best practices.

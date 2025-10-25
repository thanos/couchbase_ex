defmodule CouchbaseEx do
  @moduledoc """
  An Elixir client for Couchbase Server using a Zig port for high-performance operations.

  ## Features

  - High-performance operations via Zig port
  - Full CRUD operations (get, set, upsert, delete, insert, replace)
  - Subdocument operations
  - N1QL query support
  - Connection pooling and management
  - Comprehensive error handling
  - Timeout and resource management

  ## Quick Start

      {:ok, client} = CouchbaseEx.connect("couchbase://localhost", "Administrator", "password")

      # Basic operations
      CouchbaseEx.set(client, "key1", %{name: "John", age: 30})
      {:ok, document} = CouchbaseEx.get(client, "key1")

      # N1QL queries
      {:ok, results} = CouchbaseEx.query(client, "SELECT * FROM `default` WHERE age > 25")

      CouchbaseEx.close(client)

  ## Configuration

  You can configure the client using environment variables or options:

      # Environment variables
      export COUCHBASE_HOST="couchbase://localhost"
      export COUCHBASE_USER="Administrator"
      export COUCHBASE_PASSWORD="password"
      export COUCHBASE_BUCKET="default"

      # Or pass options directly
      {:ok, client} = CouchbaseEx.connect("couchbase://localhost", "Administrator", "password",
        bucket: "default",
        timeout: 5000,
        pool_size: 10
      )
  """

  alias CouchbaseEx.{Client, Error, Options, Config}

  @type client :: Client.t()
  @type key :: String.t()
  @type value :: any()
  @type options :: keyword() | Options.t()
  @type result :: {:ok, any()} | {:error, Error.t()}

  @doc """
  Connects to a Couchbase cluster using configuration.

  ## Parameters

  - `opts` - Optional configuration (see `CouchbaseEx.Options`)

  ## Examples

      {:ok, client} = CouchbaseEx.connect()
      {:ok, client} = CouchbaseEx.connect(bucket: "my_bucket", timeout: 10000)

  """
  @spec connect(options()) :: result()
  def connect(opts \\ []) do
    config = Config.connection_config()
    Client.connect(config.connection_string, config.username, config.password, opts)
  end

  @doc """
  Connects to a Couchbase cluster with explicit parameters.

  ## Parameters

  - `connection_string` - Couchbase connection string (e.g., "couchbase://localhost")
  - `username` - Username for authentication
  - `password` - Password for authentication
  - `opts` - Optional configuration (see `CouchbaseEx.Options`)

  ## Examples

      {:ok, client} = CouchbaseEx.connect("couchbase://localhost", "Administrator", "password")
      {:ok, client} = CouchbaseEx.connect("couchbase://localhost", "Administrator", "password", 
        bucket: "my_bucket", timeout: 10000)

  """
  @spec connect(String.t(), String.t(), String.t(), options()) :: result()
  def connect(connection_string, username, password, opts) do
    Client.connect(connection_string, username, password, opts)
  end

  @doc """
  Closes the connection to Couchbase.

  ## Examples

      CouchbaseEx.close(client)

  """
  @spec close(client()) :: :ok
  def close(client) do
    Client.close(client)
  end

  @doc """
  Gets a document by key.

  ## Parameters

  - `client` - The Couchbase client
  - `key` - Document key
  - `opts` - Optional parameters (timeout, etc.)

  ## Examples

      {:ok, document} = CouchbaseEx.get(client, "user:123")
      {:ok, document} = CouchbaseEx.get(client, "user:123", timeout: 5000)

  """
  @spec get(client(), key(), options()) :: result()
  def get(client, key, opts \\ []) do
    Client.get(client, key, opts)
  end

  @doc """
  Sets a document (insert or update).

  ## Parameters

  - `client` - The Couchbase client
  - `key` - Document key
  - `value` - Document value
  - `opts` - Optional parameters (expiry, durability, etc.)

  ## Examples

      CouchbaseEx.set(client, "user:123", %{name: "John", age: 30})
      CouchbaseEx.set(client, "user:123", %{name: "John"}, expiry: 3600)

  """
  @spec set(client(), key(), value(), options()) :: result()
  def set(client, key, value, opts \\ []) do
    Client.set(client, key, value, opts)
  end

  @doc """
  Inserts a new document (fails if document exists).

  ## Parameters

  - `client` - The Couchbase client
  - `key` - Document key
  - `value` - Document value
  - `opts` - Optional parameters

  ## Examples

      CouchbaseEx.insert(client, "user:123", %{name: "John"})

  """
  @spec insert(client(), key(), value(), options()) :: result()
  def insert(client, key, value, opts \\ []) do
    Client.insert(client, key, value, opts)
  end

  @doc """
  Replaces an existing document (fails if document doesn't exist).

  ## Parameters

  - `client` - The Couchbase client
  - `key` - Document key
  - `value` - Document value
  - `opts` - Optional parameters

  ## Examples

      CouchbaseEx.replace(client, "user:123", %{name: "John Updated"})

  """
  @spec replace(client(), key(), value(), options()) :: result()
  def replace(client, key, value, opts \\ []) do
    Client.replace(client, key, value, opts)
  end

  @doc """
  Upserts a document (insert or update).

  ## Parameters

  - `client` - The Couchbase client
  - `key` - Document key
  - `value` - Document value
  - `opts` - Optional parameters

  ## Examples

      CouchbaseEx.upsert(client, "user:123", %{name: "John"})

  """
  @spec upsert(client(), key(), value(), options()) :: result()
  def upsert(client, key, value, opts \\ []) do
    Client.upsert(client, key, value, opts)
  end

  @doc """
  Deletes a document by key.

  ## Parameters

  - `client` - The Couchbase client
  - `key` - Document key
  - `opts` - Optional parameters

  ## Examples

      CouchbaseEx.delete(client, "user:123")

  """
  @spec delete(client(), key(), options()) :: result()
  def delete(client, key, opts \\ []) do
    Client.delete(client, key, opts)
  end

  @doc """
  Checks if a document exists.

  ## Parameters

  - `client` - The Couchbase client
  - `key` - Document key
  - `opts` - Optional parameters

  ## Examples

      {:ok, exists} = CouchbaseEx.exists(client, "user:123")

  """
  @spec exists(client(), key(), options()) :: result()
  def exists(client, key, opts \\ []) do
    Client.exists(client, key, opts)
  end

  @doc """
  Executes a N1QL query.

  ## Parameters

  - `client` - The Couchbase client
  - `statement` - N1QL query statement
  - `opts` - Optional parameters

  ## Examples

      {:ok, results} = CouchbaseEx.query(client, "SELECT * FROM `default` WHERE age > 25")
      {:ok, results} = CouchbaseEx.query(client, "SELECT * FROM `default` WHERE name = $1",
        params: ["John"])

  """
  @spec query(client(), String.t(), options()) :: result()
  def query(client, statement, opts \\ []) do
    Client.query(client, statement, opts)
  end

  @doc """
  Performs subdocument lookup operations.

  ## Parameters

  - `client` - The Couchbase client
  - `key` - Document key
  - `specs` - List of subdocument specs
  - `opts` - Optional parameters

  ## Examples

      specs = [
        %{op: "get", path: "name"},
        %{op: "get", path: "age"}
      ]
      {:ok, results} = CouchbaseEx.lookup_in(client, "user:123", specs)

  """
  @spec lookup_in(client(), key(), list(), options()) :: result()
  def lookup_in(client, key, specs, opts \\ []) do
    Client.lookup_in(client, key, specs, opts)
  end

  @doc """
  Performs subdocument mutation operations.

  ## Parameters

  - `client` - The Couchbase client
  - `key` - Document key
  - `specs` - List of subdocument specs
  - `opts` - Optional parameters

  ## Examples

      specs = [
        %{op: "upsert", path: "name", value: "John Updated"},
        %{op: "increment", path: "age", value: 1}
      ]
      CouchbaseEx.mutate_in(client, "user:123", specs)

  """
  @spec mutate_in(client(), key(), list(), options()) :: result()
  def mutate_in(client, key, specs, opts \\ []) do
    Client.mutate_in(client, key, specs, opts)
  end

  @doc """
  Pings the Couchbase cluster to check connectivity.

  ## Parameters

  - `client` - The Couchbase client
  - `opts` - Optional parameters

  ## Examples

      {:ok, ping_result} = CouchbaseEx.ping(client)

  """
  @spec ping(client(), options()) :: result()
  def ping(client, opts \\ []) do
    Client.ping(client, opts)
  end

  @doc """
  Gets cluster diagnostics information.

  ## Parameters

  - `client` - The Couchbase client
  - `opts` - Optional parameters

  ## Examples

      {:ok, diagnostics} = CouchbaseEx.diagnostics(client)

  """
  @spec diagnostics(client(), options()) :: result()
  def diagnostics(client, opts \\ []) do
    Client.diagnostics(client, opts)
  end
end

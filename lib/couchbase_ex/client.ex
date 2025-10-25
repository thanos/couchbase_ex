defmodule CouchbaseEx.Client do
  @moduledoc """
  The main client module that handles communication with the Zig port.

  This module manages the connection to the Zig server process and provides
  the core functionality for all Couchbase operations.
  """

  alias CouchbaseEx.{Error, Options, PortManager}

  require Logger

  defstruct [
    :port,
    :connection_string,
    :username,
    :password,
    :bucket,
    :timeout,
    :pool_size,
    :ref_counter
  ]

  @type t :: %__MODULE__{
          port: port(),
          connection_string: String.t(),
          username: String.t(),
          password: String.t(),
          bucket: String.t(),
          timeout: non_neg_integer(),
          pool_size: non_neg_integer(),
          ref_counter: :counters.counters_ref()
        }

  @doc """
  Connects to a Couchbase cluster.

  ## Parameters

  - `connection_string` - Couchbase connection string
  - `username` - Username for authentication
  - `password` - Password for authentication
  - `opts` - Optional configuration

  ## Returns

  - `{:ok, client}` - Successfully connected client
  - `{:error, reason}` - Connection failed

  ## Examples

      {:ok, client} = CouchbaseEx.Client.connect("couchbase://localhost", "admin", "password")
      {:ok, client} = CouchbaseEx.Client.connect("couchbase://localhost", "admin", "password",
        bucket: "my_bucket", timeout: 10000)

  """
  @spec connect(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def connect(connection_string, username, password, opts \\ []) do
    options = Options.new(opts)

    # Validate connection parameters before attempting to start PortManager
    case validate_connection_params(connection_string, username, password) do
      :ok ->
        case PortManager.start_link(connection_string, username, password, options) do
          {:ok, port_pid} ->
            client = %__MODULE__{
              port: port_pid,
              connection_string: connection_string,
              username: username,
              password: password,
              bucket: options.bucket,
              timeout: options.timeout,
              pool_size: options.pool_size,
              ref_counter: :counters.new(1, [:atomics])
            }

            # Initialize connection
            case send_command(client, "connect", %{
                   connection_string: connection_string,
                   username: username,
                   password: password,
                   bucket: options.bucket,
                   timeout: options.timeout
                 }) do
              {:ok, _} -> {:ok, client}
              {:error, reason} -> {:error, reason}
            end

          {:error, reason} ->
            error_message = if is_binary(reason), do: reason, else: inspect(reason)
            {:error, Error.new(:connection_failed, error_message)}
        end

      {:error, reason} ->
        {:error, Error.new(:invalid_connection_params, reason)}
    end
  end

  @doc """
  Closes the client connection.

  ## Parameters

  - `client` - The client to close

  ## Examples

      CouchbaseEx.Client.close(client)

  """
  @spec close(t()) :: :ok
  def close(client) do
    send_command(client, "close", %{})
    PortManager.stop(client.port)
    :ok
  end

  @doc """
  Gets a document by key.

  ## Parameters

  - `client` - The Couchbase client
  - `key` - Document key
  - `opts` - Optional parameters

  ## Returns

  - `{:ok, document}` - Document retrieved successfully
  - `{:error, reason}` - Operation failed

  ## Examples

      {:ok, document} = CouchbaseEx.Client.get(client, "user:123")
      {:ok, document} = CouchbaseEx.Client.get(client, "user:123", timeout: 5000)

  """
  @spec get(t(), String.t(), keyword()) :: {:ok, any()} | {:error, Error.t()}
  def get(client, key, opts \\ []) do
    options = Options.new(opts)
    send_command(client, "get", %{key: key, timeout: options.timeout})
  end

  @doc """
  Sets a document (insert or update).

  ## Parameters

  - `client` - The Couchbase client
  - `key` - Document key
  - `value` - Document value
  - `opts` - Optional parameters

  ## Returns

  - `{:ok, result}` - Operation successful
  - `{:error, reason}` - Operation failed

  ## Examples

      CouchbaseEx.Client.set(client, "user:123", %{name: "John"})
      CouchbaseEx.Client.set(client, "user:123", %{name: "John"}, expiry: 3600)

  """
  @spec set(t(), String.t(), any(), keyword()) :: {:ok, any()} | {:error, Error.t()}
  def set(client, key, value, opts \\ []) do
    options = Options.new(opts)

    send_command(client, "set", %{
      key: key,
      value: value,
      expiry: options.expiry,
      durability: options.durability,
      timeout: options.timeout
    })
  end

  @doc """
  Inserts a new document (fails if document exists).

  ## Parameters

  - `client` - The Couchbase client
  - `key` - Document key
  - `value` - Document value
  - `opts` - Optional parameters

  ## Returns

  - `{:ok, result}` - Operation successful
  - `{:error, reason}` - Operation failed

  ## Examples

      CouchbaseEx.Client.insert(client, "user:123", %{name: "John"})

  """
  @spec insert(t(), String.t(), any(), keyword()) :: {:ok, any()} | {:error, Error.t()}
  def insert(client, key, value, opts \\ []) do
    options = Options.new(opts)

    send_command(client, "insert", %{
      key: key,
      value: value,
      expiry: options.expiry,
      durability: options.durability,
      timeout: options.timeout
    })
  end

  @doc """
  Replaces an existing document (fails if document doesn't exist).

  ## Parameters

  - `client` - The Couchbase client
  - `key` - Document key
  - `value` - Document value
  - `opts` - Optional parameters

  ## Returns

  - `{:ok, result}` - Operation successful
  - `{:error, reason}` - Operation failed

  ## Examples

      CouchbaseEx.Client.replace(client, "user:123", %{name: "John Updated"})

  """
  @spec replace(t(), String.t(), any(), keyword()) :: {:ok, any()} | {:error, Error.t()}
  def replace(client, key, value, opts \\ []) do
    options = Options.new(opts)

    send_command(client, "replace", %{
      key: key,
      value: value,
      expiry: options.expiry,
      durability: options.durability,
      timeout: options.timeout
    })
  end

  @doc """
  Upserts a document (insert or update).

  ## Parameters

  - `client` - The Couchbase client
  - `key` - Document key
  - `value` - Document value
  - `opts` - Optional parameters

  ## Returns

  - `{:ok, result}` - Operation successful
  - `{:error, reason}` - Operation failed

  ## Examples

      CouchbaseEx.Client.upsert(client, "user:123", %{name: "John"})

  """
  @spec upsert(t(), String.t(), any(), keyword()) :: {:ok, any()} | {:error, Error.t()}
  def upsert(client, key, value, opts \\ []) do
    options = Options.new(opts)

    send_command(client, "upsert", %{
      key: key,
      value: value,
      expiry: options.expiry,
      durability: options.durability,
      timeout: options.timeout
    })
  end

  @doc """
  Deletes a document by key.

  ## Parameters

  - `client` - The Couchbase client
  - `key` - Document key
  - `opts` - Optional parameters

  ## Returns

  - `{:ok, result}` - Operation successful
  - `{:error, reason}` - Operation failed

  ## Examples

      CouchbaseEx.Client.delete(client, "user:123")

  """
  @spec delete(t(), String.t(), keyword()) :: {:ok, any()} | {:error, Error.t()}
  def delete(client, key, opts \\ []) do
    options = Options.new(opts)

    send_command(client, "delete", %{
      key: key,
      durability: options.durability,
      timeout: options.timeout
    })
  end

  @doc """
  Checks if a document exists.

  ## Parameters

  - `client` - The Couchbase client
  - `key` - Document key
  - `opts` - Optional parameters

  ## Returns

  - `{:ok, boolean}` - Document exists or not
  - `{:error, reason}` - Operation failed

  ## Examples

      {:ok, exists} = CouchbaseEx.Client.exists(client, "user:123")

  """
  @spec exists(t(), String.t(), keyword()) :: {:ok, boolean()} | {:error, Error.t()}
  def exists(client, key, opts \\ []) do
    options = Options.new(opts)
    send_command(client, "exists", %{key: key, timeout: options.timeout})
  end

  @doc """
  Executes a N1QL query.

  ## Parameters

  - `client` - The Couchbase client
  - `statement` - N1QL query statement
  - `opts` - Optional parameters

  ## Returns

  - `{:ok, results}` - Query results
  - `{:error, reason}` - Operation failed

  ## Examples

      {:ok, results} = CouchbaseEx.Client.query(client, "SELECT * FROM `default`")
      {:ok, results} = CouchbaseEx.Client.query(client, "SELECT * FROM `default` WHERE name = $1",
        params: ["John"])

  """
  @spec query(t(), String.t(), keyword()) :: {:ok, list()} | {:error, Error.t()}
  def query(client, statement, opts \\ []) do
    options = Options.new(opts)

    send_command(client, "query", %{
      statement: statement,
      params: options.params,
      timeout: options.timeout
    })
  end

  @doc """
  Performs subdocument lookup operations.

  ## Parameters

  - `client` - The Couchbase client
  - `key` - Document key
  - `specs` - List of subdocument specs
  - `opts` - Optional parameters

  ## Returns

  - `{:ok, results}` - Lookup results
  - `{:error, reason}` - Operation failed

  ## Examples

      specs = [%{op: "get", path: "name"}, %{op: "get", path: "age"}]
      {:ok, results} = CouchbaseEx.Client.lookup_in(client, "user:123", specs)

  """
  @spec lookup_in(t(), String.t(), list(), keyword()) :: {:ok, list()} | {:error, Error.t()}
  def lookup_in(client, key, specs, opts \\ []) do
    options = Options.new(opts)

    send_command(client, "lookup_in", %{
      key: key,
      specs: specs,
      timeout: options.timeout
    })
  end

  @doc """
  Performs subdocument mutation operations.

  ## Parameters

  - `client` - The Couchbase client
  - `key` - Document key
  - `specs` - List of subdocument specs
  - `opts` - Optional parameters

  ## Returns

  - `{:ok, results}` - Mutation results
  - `{:error, reason}` - Operation failed

  ## Examples

      specs = [%{op: "upsert", path: "name", value: "John Updated"}]
      CouchbaseEx.Client.mutate_in(client, "user:123", specs)

  """
  @spec mutate_in(t(), String.t(), list(), keyword()) :: {:ok, list()} | {:error, Error.t()}
  def mutate_in(client, key, specs, opts \\ []) do
    options = Options.new(opts)

    send_command(client, "mutate_in", %{
      key: key,
      specs: specs,
      expiry: options.expiry,
      durability: options.durability,
      timeout: options.timeout
    })
  end

  @doc """
  Pings the Couchbase cluster.

  ## Parameters

  - `client` - The Couchbase client
  - `opts` - Optional parameters

  ## Returns

  - `{:ok, ping_result}` - Ping results
  - `{:error, reason}` - Operation failed

  ## Examples

      {:ok, ping_result} = CouchbaseEx.Client.ping(client)

  """
  @spec ping(t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def ping(client, opts \\ []) do
    options = Options.new(opts)
    send_command(client, "ping", %{timeout: options.timeout})
  end

  @doc """
  Gets cluster diagnostics.

  ## Parameters

  - `client` - The Couchbase client
  - `opts` - Optional parameters

  ## Returns

  - `{:ok, diagnostics}` - Diagnostics information
  - `{:error, reason}` - Operation failed

  ## Examples

      {:ok, diagnostics} = CouchbaseEx.Client.diagnostics(client)

  """
  @spec diagnostics(t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def diagnostics(client, opts \\ []) do
    options = Options.new(opts)
    send_command(client, "diagnostics", %{timeout: options.timeout})
  end

  # Private functions

  @spec validate_connection_params(String.t(), String.t(), String.t()) ::
          :ok | {:error, String.t()}
  defp validate_connection_params(connection_string, username, password) do
    cond do
      is_nil(connection_string) or connection_string == "" ->
        {:error, "Connection string cannot be empty"}

      is_nil(username) or username == "" ->
        {:error, "Username cannot be empty"}

      is_nil(password) or password == "" ->
        {:error, "Password cannot be empty"}

      not String.starts_with?(connection_string, "couchbase://") ->
        {:error, "Invalid connection string format. Must start with 'couchbase://'"}

      true ->
        :ok
    end
  end

  @spec send_command(t(), String.t(), map()) :: {:ok, any()} | {:error, Error.t()}
  defp send_command(client, command, params) do
    if is_nil(client.port) do
      {:error, Error.new(:not_connected, "Client not connected to Couchbase")}
    else
      message = %{
        command: command,
        params: params,
        timestamp: System.monotonic_time(:millisecond)
      }

      case PortManager.send_command(client.port, message) do
        {:ok, response} ->
          case response do
            %{"success" => true, "data" => data} -> {:ok, data}
            %{"success" => false, "error" => error} -> {:error, Error.from_map(error)}
            _ -> {:error, Error.new(:invalid_response, "Unexpected response format")}
          end

        {:error, reason} ->
          {:error, Error.new(:communication_failed, to_string(reason))}
      end
    end
  end
end

defmodule CouchbaseEx.Config do
  @moduledoc """
  Configuration management for CouchbaseEx.

  This module provides a centralized way to access configuration values
  with proper defaults and environment variable support.
  """

  @doc """
  Gets the Couchbase connection string.

  ## Returns

  - `String.t()` - Connection string

  ## Examples

      Config.connection_string()  # "couchbase://localhost"

  """
  @spec connection_string() :: String.t()
  def connection_string do
    Application.get_env(:couchbase_ex, :connection_string, "couchbase://localhost")
  end

  @doc """
  Gets the Couchbase username.

  ## Returns

  - `String.t()` - Username

  ## Examples

      Config.username()  # "Administrator"

  """
  @spec username() :: String.t()
  def username do
    Application.get_env(:couchbase_ex, :username, "Administrator")
  end

  @doc """
  Gets the Couchbase password.

  ## Returns

  - `String.t()` - Password

  ## Examples

      Config.password()  # "password"

  """
  @spec password() :: String.t()
  def password do
    Application.get_env(:couchbase_ex, :password, "password")
  end

  @doc """
  Gets the default bucket name.

  ## Returns

  - `String.t()` - Bucket name

  ## Examples

      Config.bucket()  # "default"

  """
  @spec bucket() :: String.t()
  def bucket do
    Application.get_env(:couchbase_ex, :bucket, "default")
  end

  @doc """
  Gets the default timeout in milliseconds.

  ## Returns

  - `non_neg_integer()` - Timeout in milliseconds

  ## Examples

      Config.timeout()  # 5000

  """
  @spec timeout() :: non_neg_integer()
  def timeout do
    Application.get_env(:couchbase_ex, :timeout, 5000)
  end

  @doc """
  Gets the connection pool size.

  ## Returns

  - `non_neg_integer()` - Pool size

  ## Examples

      Config.pool_size()  # 10

  """
  @spec pool_size() :: non_neg_integer()
  def pool_size do
    Application.get_env(:couchbase_ex, :pool_size, 10)
  end

  @doc """
  Gets the connection timeout in milliseconds.

  ## Returns

  - `non_neg_integer()` - Connection timeout in milliseconds

  ## Examples

      Config.connection_timeout()  # 10000

  """
  @spec connection_timeout() :: non_neg_integer()
  def connection_timeout do
    Application.get_env(:couchbase_ex, :connection_timeout, 10_000)
  end

  @doc """
  Gets the query timeout in milliseconds.

  ## Returns

  - `non_neg_integer()` - Query timeout in milliseconds

  ## Examples

      Config.query_timeout()  # 30000

  """
  @spec query_timeout() :: non_neg_integer()
  def query_timeout do
    Application.get_env(:couchbase_ex, :query_timeout, 30_000)
  end

  @doc """
  Gets the operation timeout in milliseconds.

  ## Returns

  - `non_neg_integer()` - Operation timeout in milliseconds

  ## Examples

      Config.operation_timeout()  # 5000

  """
  @spec operation_timeout() :: non_neg_integer()
  def operation_timeout do
    Application.get_env(:couchbase_ex, :operation_timeout, 5000)
  end

  @doc """
  Gets all connection configuration as a map.

  ## Returns

  - `map()` - Connection configuration

  ## Examples

      Config.connection_config()
      # %{
      #   connection_string: "couchbase://localhost",
      #   username: "Administrator",
      #   password: "password",
      #   bucket: "default",
      #   timeout: 5000,
      #   pool_size: 10
      # }

  """
  @spec connection_config() :: map()
  def connection_config do
    %{
      connection_string: connection_string(),
      username: username(),
      password: password(),
      bucket: bucket(),
      timeout: timeout(),
      pool_size: pool_size(),
      connection_timeout: connection_timeout(),
      query_timeout: query_timeout(),
      operation_timeout: operation_timeout()
    }
  end

  @doc """
  Gets the Zig server configuration.

  ## Returns

  - `map()` - Zig server configuration

  ## Examples

      Config.zig_server_config()
      # %{
      #   executable_path: "/path/to/couchbase_zig_server",
      #   build_on_startup: false
      # }

  """
  @spec zig_server_config() :: map()
  def zig_server_config do
    Application.get_env(:couchbase_ex, :zig_server, %{})
  end

  @doc """
  Gets the Zig server executable path.

  ## Returns

  - `String.t() | nil` - Executable path or nil if not configured

  ## Examples

      Config.zig_server_path()  # "/path/to/couchbase_zig_server"

  """
  @spec zig_server_path() :: String.t() | nil
  def zig_server_path do
    zig_server_config()[:executable_path]
  end

  @doc """
  Checks if the Zig server should be built on startup.

  ## Returns

  - `boolean()` - Whether to build on startup

  ## Examples

      Config.build_zig_server_on_startup?()  # false

  """
  @spec build_zig_server_on_startup?() :: boolean()
  def build_zig_server_on_startup? do
    zig_server_config()[:build_on_startup] || false
  end

  @doc """
  Validates the configuration and returns any errors.

  ## Returns

  - `:ok` - Configuration is valid
  - `{:error, [String.t()]}` - List of validation errors

  ## Examples

      Config.validate()  # :ok
      Config.validate()  # {:error, ["Connection string is required"]}

  """
  @spec validate() :: :ok | {:error, [String.t()]}
  def validate do
    errors =
      []
      |> validate_connection_string()
      |> validate_username()
      |> validate_password()
      |> validate_bucket()
      |> validate_timeouts()

    case errors do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  # Private validation functions

  @spec validate_connection_string([String.t()]) :: [String.t()]
  defp validate_connection_string(errors) do
    connection_string = connection_string()

    if is_nil(connection_string) or connection_string == "" do
      ["Connection string is required" | errors]
    else
      errors
    end
  end

  @spec validate_username([String.t()]) :: [String.t()]
  defp validate_username(errors) do
    username = username()

    if is_nil(username) or username == "" do
      ["Username is required" | errors]
    else
      errors
    end
  end

  @spec validate_password([String.t()]) :: [String.t()]
  defp validate_password(errors) do
    password = password()

    if is_nil(password) or password == "" do
      ["Password is required" | errors]
    else
      errors
    end
  end

  @spec validate_bucket([String.t()]) :: [String.t()]
  defp validate_bucket(errors) do
    bucket = bucket()

    if is_nil(bucket) or bucket == "" do
      ["Bucket name is required" | errors]
    else
      errors
    end
  end

  @spec validate_timeouts([String.t()]) :: [String.t()]
  defp validate_timeouts(errors) do
    errors
    |> validate_timeout(:timeout, timeout())
    |> validate_timeout(:connection_timeout, connection_timeout())
    |> validate_timeout(:query_timeout, query_timeout())
    |> validate_timeout(:operation_timeout, operation_timeout())
  end

  @spec validate_timeout([String.t()], atom(), non_neg_integer()) :: [String.t()]
  defp validate_timeout(errors, _name, timeout) when is_integer(timeout) and timeout > 0 do
    errors
  end

  defp validate_timeout(errors, name, _timeout) do
    ["#{name} must be a positive integer" | errors]
  end
end

defmodule CouchbaseEx.Options do
  @moduledoc """
  Configuration options for CouchbaseEx operations.

  This module provides a structured way to handle configuration options
  for all Couchbase operations, with sensible defaults and validation.
  """

  defstruct [
    :bucket,
    :timeout,
    :expiry,
    :durability,
    :params,
    :pool_size,
    :connection_timeout,
    :query_timeout,
    :operation_timeout
  ]

  @type t :: %__MODULE__{
          bucket: String.t(),
          timeout: non_neg_integer(),
          expiry: non_neg_integer() | nil,
          durability: atom(),
          params: list(),
          pool_size: non_neg_integer(),
          connection_timeout: non_neg_integer(),
          query_timeout: non_neg_integer(),
          operation_timeout: non_neg_integer()
        }

  @doc """
  Creates a new Options struct with the given keyword list.

  ## Parameters

  - `opts` - Keyword list of options

  ## Returns

  - `t()` - Options struct with defaults applied

  ## Examples

      Options.new([bucket: "my_bucket", timeout: 5000])
      Options.new([expiry: 3600, durability: :majority])

  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      bucket: Keyword.get(opts, :bucket, get_default_bucket()),
      timeout: Keyword.get(opts, :timeout, 5_000),
      expiry: Keyword.get(opts, :expiry),
      durability: Keyword.get(opts, :durability, :none),
      params: Keyword.get(opts, :params, []),
      pool_size: Keyword.get(opts, :pool_size, 10),
      connection_timeout: Keyword.get(opts, :connection_timeout, 10_000),
      query_timeout: Keyword.get(opts, :query_timeout, 30_000),
      operation_timeout: Keyword.get(opts, :operation_timeout, 5_000)
    }
  end

  @doc """
  Gets the default bucket name from environment variables or returns "default".

  ## Returns

  - `String.t()` - Default bucket name

  ## Examples

      Options.get_default_bucket()  # "default" or from COUCHBASE_BUCKET env var

  """
  @spec get_default_bucket() :: String.t()
  def get_default_bucket do
    System.get_env("COUCHBASE_BUCKET", "default")
  end

  @doc """
  Gets the default connection string from environment variables.

  ## Returns

  - `String.t()` - Default connection string

  ## Examples

      Options.get_default_connection_string()  # "couchbase://localhost" or from COUCHBASE_HOST

  """
  @spec get_default_connection_string() :: String.t()
  def get_default_connection_string do
    System.get_env("COUCHBASE_HOST", "couchbase://localhost")
  end

  @doc """
  Gets the default username from environment variables.

  ## Returns

  - `String.t()` - Default username

  ## Examples

      Options.get_default_username()  # "Administrator" or from COUCHBASE_USER

  """
  @spec get_default_username() :: String.t()
  def get_default_username do
    System.get_env("COUCHBASE_USER", "Administrator")
  end

  @doc """
  Gets the default password from environment variables.

  ## Returns

  - `String.t()` - Default password

  ## Examples

      Options.get_default_password()  # "password" or from COUCHBASE_PASSWORD

  """
  @spec get_default_password() :: String.t()
  def get_default_password do
    System.get_env("COUCHBASE_PASSWORD", "password")
  end

  @doc """
  Validates the options and returns any validation errors.

  ## Parameters

  - `options` - Options to validate

  ## Returns

  - `:ok` - Options are valid
  - `{:error, [String.t()]}` - List of validation errors

  ## Examples

      Options.validate(%Options{bucket: "my_bucket", timeout: 5000})  # :ok
      Options.validate(%Options{bucket: "", timeout: -1})  # {:error, ["Bucket cannot be empty", "Timeout must be positive"]}

  """
  @spec validate(t()) :: :ok | {:error, [String.t()]}
  def validate(%__MODULE__{} = options) do
    errors =
      []
      |> validate_bucket(options.bucket)
      |> validate_timeout(options.timeout)
      |> validate_expiry(options.expiry)
      |> validate_durability(options.durability)
      |> validate_pool_size(options.pool_size)

    case errors do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  @doc """
  Merges two options structs, with the second taking precedence.

  ## Parameters

  - `options1` - First options struct
  - `options2` - Second options struct

  ## Returns

  - `t()` - Merged options struct

  ## Examples

      Options.merge(options1, options2)

  """
  @spec merge(t(), t()) :: t()
  def merge(%__MODULE__{} = options1, %__MODULE__{} = options2) do
    %__MODULE__{
      bucket: if(is_nil(options2.bucket), do: options1.bucket, else: options2.bucket),
      timeout: if(is_nil(options2.timeout), do: options1.timeout, else: options2.timeout),
      expiry: if(is_nil(options2.expiry), do: options1.expiry, else: options2.expiry),
      durability:
        if(is_nil(options2.durability), do: options1.durability, else: options2.durability),
      params: if(is_nil(options2.params), do: options1.params, else: options2.params),
      pool_size: if(is_nil(options2.pool_size), do: options1.pool_size, else: options2.pool_size),
      connection_timeout:
        if(is_nil(options2.connection_timeout),
          do: options1.connection_timeout,
          else: options2.connection_timeout
        ),
      query_timeout:
        if(is_nil(options2.query_timeout),
          do: options1.query_timeout,
          else: options2.query_timeout
        ),
      operation_timeout:
        if(is_nil(options2.operation_timeout),
          do: options1.operation_timeout,
          else: options2.operation_timeout
        )
    }
  end

  @doc """
  Converts options to a map for serialization.

  ## Parameters

  - `options` - Options to convert

  ## Returns

  - `map()` - Options as a map

  ## Examples

      Options.to_map(%Options{bucket: "my_bucket", timeout: 5000})
      # %{"bucket" => "my_bucket", "timeout" => 5000, ...}

  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = options) do
    %{
      "bucket" => options.bucket,
      "timeout" => options.timeout,
      "expiry" => options.expiry,
      "durability" => Atom.to_string(options.durability),
      "params" => options.params,
      "pool_size" => options.pool_size,
      "connection_timeout" => options.connection_timeout,
      "query_timeout" => options.query_timeout,
      "operation_timeout" => options.operation_timeout
    }
  end

  @doc """
  Creates options from a map.

  ## Parameters

  - `options_map` - Map containing options

  ## Returns

  - `t()` - Options struct

  ## Examples

      Options.from_map(%{"bucket" => "my_bucket", "timeout" => 5000})

  """
  @spec from_map(map()) :: t()
  def from_map(options_map) do
    %__MODULE__{
      bucket: Map.get(options_map, "bucket", get_default_bucket()),
      timeout: Map.get(options_map, "timeout", 5_000),
      expiry: Map.get(options_map, "expiry"),
      durability: Map.get(options_map, "durability", "none") |> String.to_atom(),
      params: Map.get(options_map, "params", []),
      pool_size: Map.get(options_map, "pool_size", 10),
      connection_timeout: Map.get(options_map, "connection_timeout", 10_000),
      query_timeout: Map.get(options_map, "query_timeout", 30_000),
      operation_timeout: Map.get(options_map, "operation_timeout", 5_000)
    }
  end

  # Private functions

  @spec validate_bucket([String.t()], String.t()) :: [String.t()]
  defp validate_bucket(errors, bucket) when is_binary(bucket) and byte_size(bucket) > 0 do
    errors
  end

  defp validate_bucket(errors, _bucket) do
    ["Bucket cannot be empty" | errors]
  end

  @spec validate_timeout([String.t()], non_neg_integer()) :: [String.t()]
  defp validate_timeout(errors, timeout) when is_integer(timeout) and timeout > 0 do
    errors
  end

  defp validate_timeout(errors, _timeout) do
    ["Timeout must be positive" | errors]
  end

  @spec validate_expiry([String.t()], non_neg_integer() | nil) :: [String.t()]
  defp validate_expiry(errors, nil) do
    errors
  end

  defp validate_expiry(errors, expiry) when is_integer(expiry) and expiry >= 0 do
    errors
  end

  defp validate_expiry(errors, _expiry) do
    ["Expiry must be non-negative" | errors]
  end

  @spec validate_durability([String.t()], atom()) :: [String.t()]
  defp validate_durability(errors, durability)
       when durability in [:none, :majority, :majority_and_persist, :persist_to_majority] do
    errors
  end

  defp validate_durability(errors, _durability) do
    [
      "Durability must be one of: :none, :majority, :majority_and_persist, :persist_to_majority"
      | errors
    ]
  end

  @spec validate_pool_size([String.t()], non_neg_integer()) :: [String.t()]
  defp validate_pool_size(errors, pool_size) when is_integer(pool_size) and pool_size > 0 do
    errors
  end

  defp validate_pool_size(errors, _pool_size) do
    ["Pool size must be positive" | errors]
  end
end

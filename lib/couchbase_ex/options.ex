defmodule CouchbaseEx.Options do
  @moduledoc """
  Configuration options for CouchbaseEx operations.

  This module provides a structured way to handle configuration options
  for all Couchbase operations, with sensible defaults and validation using nimble_options.
  """

  # No need for use NimbleOptions, we'll use it directly

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

  @schema [
    bucket: [
      type: :string,
      default: "default",
      doc: "The Couchbase bucket name"
    ],
    timeout: [
      type: :non_neg_integer,
      default: 5_000,
      doc: "Default operation timeout in milliseconds"
    ],
    expiry: [
      type: {:or, [:non_neg_integer, :nil]},
      default: nil,
      doc: "Document expiry time in seconds (nil for no expiry)"
    ],
    durability: [
      type: {:in, [:none, :majority, :majority_and_persist, :persist_to_majority]},
      default: :none,
      doc: "Durability level for write operations"
    ],
    params: [
      type: {:list, :any},
      default: [],
      doc: "Parameters for parameterized queries"
    ],
    pool_size: [
      type: :non_neg_integer,
      default: 10,
      doc: "Connection pool size"
    ],
    connection_timeout: [
      type: :non_neg_integer,
      default: 10_000,
      doc: "Connection establishment timeout in milliseconds"
    ],
    query_timeout: [
      type: :non_neg_integer,
      default: 30_000,
      doc: "N1QL query timeout in milliseconds"
    ],
    operation_timeout: [
      type: :non_neg_integer,
      default: 5_000,
      doc: "Individual operation timeout in milliseconds"
    ]
  ]

  @doc """
  Creates a new Options struct with the given keyword list.

  ## Parameters

  - `opts` - Keyword list of options

  ## Returns

  - `{:ok, t()}` - Options struct with defaults applied
  - `{:error, NimbleOptions.ValidationError.t()}` - Validation error

  ## Examples

      Options.new([bucket: "my_bucket", timeout: 5000])
      Options.new([expiry: 3600, durability: :majority])

  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    # Merge with environment variables for bucket default
    opts = Keyword.put_new(opts, :bucket, get_default_bucket())

    validated_opts = validate!(opts)
    struct(__MODULE__, validated_opts)
  end

  @doc """
  Creates a new Options struct with the given keyword list, raising on error.

  ## Parameters

  - `opts` - Keyword list of options

  ## Returns

  - `t()` - Options struct with defaults applied

  ## Raises

  - `NimbleOptions.ValidationError` - If validation fails

  ## Examples

      Options.new!([bucket: "my_bucket", timeout: 5000])
      Options.new!([expiry: 3600, durability: :majority])

  """
  @spec new!(keyword()) :: t()
  def new!(opts \\ []) do
    # Merge with environment variables for bucket default
    opts = Keyword.put_new(opts, :bucket, get_default_bucket())

    validated_opts = validate!(opts)
    struct(__MODULE__, validated_opts)
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

  - `opts` - Keyword list of options to validate

  ## Returns

  - `{:ok, keyword()}` - Validated options
  - `{:error, NimbleOptions.ValidationError.t()}` - Validation error

  ## Examples

      Options.validate([bucket: "my_bucket", timeout: 5000])  # {:ok, [bucket: "my_bucket", timeout: 5000]}
      Options.validate([bucket: "", timeout: -1])  # {:error, %NimbleOptions.ValidationError{}}

  """
  @spec validate(keyword()) :: {:ok, keyword()} | {:error, NimbleOptions.ValidationError.t()}
  def validate(opts) do
    NimbleOptions.validate(opts, @schema)
  end

  @doc """
  Validates an Options struct and returns any validation errors.

  ## Parameters

  - `options` - Options struct to validate

  ## Returns

  - `:ok` - Options are valid
  - `{:error, [String.t()]}` - List of validation errors

  ## Examples

      Options.validate_struct(%Options{bucket: "my_bucket", timeout: 5000})  # :ok
      Options.validate_struct(%Options{bucket: "", timeout: -1})  # {:error, ["Bucket cannot be empty", "Timeout must be positive"]}

  """
  @spec validate_struct(t()) :: :ok | {:error, [String.t()]}
  def validate_struct(%__MODULE__{} = options) do
    # Convert struct to keyword list for validation, handling nil values
    opts = [
      bucket: options.bucket,
      timeout: options.timeout,
      expiry: options.expiry,
      durability: options.durability,
      params: options.params || [],
      pool_size: options.pool_size,
      connection_timeout: options.connection_timeout || 10_000,
      query_timeout: options.query_timeout || 30_000,
      operation_timeout: options.operation_timeout || 5_000
    ]

    case NimbleOptions.validate(opts, @schema) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, [error.message]}
    end
  end

  @doc """
  Validates the options and raises on error.

  ## Parameters

  - `opts` - Keyword list of options to validate

  ## Returns

  - `keyword()` - Validated options

  ## Raises

  - `NimbleOptions.ValidationError` - If validation fails

  ## Examples

      Options.validate!([bucket: "my_bucket", timeout: 5000])  # [bucket: "my_bucket", timeout: 5000]

  """
  @spec validate!(keyword()) :: keyword()
  def validate!(opts) do
    NimbleOptions.validate!(opts, @schema)
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

end

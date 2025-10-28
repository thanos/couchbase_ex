defmodule CouchbaseEx.Error do
  @moduledoc """
  Error handling for CouchbaseEx operations.

  This module provides comprehensive error handling for all Couchbase operations,
  including error conversion from the Zig port and idiomatic Elixir error types.
  """

  defexception [:reason, :message, :details]

  @type t :: %__MODULE__{
          reason: atom(),
          message: String.t(),
          details: map() | nil
        }

  @doc """
  Creates a new error with the given reason and message.

  ## Parameters

  - `reason` - The error reason (atom)
  - `message` - Error message
  - `details` - Optional error details

  ## Examples

      Error.new(:connection_failed, "Unable to connect to cluster")
      Error.new(:document_not_found, "Document with key 'user:123' not found", %{key: "user:123"})

  """
  @spec new(atom(), String.t(), map() | nil) :: t()
  def new(reason, message, details \\ nil) do
    %__MODULE__{
      reason: reason,
      message: message,
      details: details
    }
  end

  @doc """
  Creates an error from a map (typically from Zig port response).

  ## Parameters

  - `error_map` - Map containing error information

  ## Examples

      Error.from_map(%{"code" => "DOCUMENT_NOT_FOUND", "message" => "Document not found"})

  """
  @spec from_map(map()) :: t()
  def from_map(error_map) when is_map(error_map) do
    reason =
      error_map
      |> Map.get("code", "UNKNOWN_ERROR")
      |> zig_to_elixir_reason()

    message = Map.get(error_map, "message", "Unknown error occurred")
    details = Map.get(error_map, "details", %{})

    new(reason, message, details)
  end

  @doc """
  Creates an error from a Zig port response.

  Handles both structured error responses (with code/message) and simple string errors.

  ## Parameters

  - `response` - Response from Zig port (map or string)

  ## Examples

      Error.from_response(%{"success" => false, "data" => %{"code" => "DocumentNotFound", "message" => "..."}})
      Error.from_response("Connection failed")

  """
  @spec from_response(map() | String.t()) :: t()
  def from_response(%{"data" => data} = response) when is_map(data) do
    # Structured error response with code and message
    if Map.has_key?(data, "code") do
      from_map(data)
    else
      # Fallback to error field
      error_msg = Map.get(response, "error", "Unknown error")
      new(:operation_failed, error_msg, data)
    end
  end

  def from_response(%{"error" => error_msg}) when is_binary(error_msg) do
    # Simple error message
    parse_error_message(error_msg)
  end

  def from_response(error_string) when is_binary(error_string) do
    # Plain string error
    parse_error_message(error_string)
  end

  def from_response(_) do
    # Unknown error format
    new(:unknown_error, "Unknown error occurred")
  end

  @doc """
  Parses an error message string to extract error code and context.

  ## Parameters

  - `error_msg` - Error message string

  ## Examples

      Error.parse_error_message("DocumentNotFound: user:123")
      Error.parse_error_message("Connection failed")

  """
  @spec parse_error_message(String.t()) :: t()
  def parse_error_message(error_msg) when is_binary(error_msg) do
    case String.split(error_msg, ":", parts: 2) do
      [code, context] ->
        reason = zig_to_elixir_reason(String.trim(code))
        new(reason, error_msg, %{context: String.trim(context)})

      [single_error] ->
        # Try to extract error code from message
        reason = zig_to_elixir_reason(single_error)
        new(reason, error_msg)
    end
  end

  @doc """
  Converts a Zig error code to an Elixir error reason.

  ## Parameters

  - `zig_code` - Error code from Zig port

  ## Returns

  - `atom()` - Elixir error reason

  ## Examples

      Error.zig_to_elixir_reason("DOCUMENT_NOT_FOUND")  # :document_not_found
      Error.zig_to_elixir_reason("CONNECTION_FAILED")   # :connection_failed

  """
  @spec zig_to_elixir_reason(String.t()) :: atom()
  def zig_to_elixir_reason(zig_code) do
    case zig_code do
      # Document errors
      "DocumentNotFound" -> :document_not_found
      "DOCUMENT_NOT_FOUND" -> :document_not_found
      "DocumentExists" -> :document_exists
      "DOCUMENT_EXISTS" -> :document_exists
      "DocumentLocked" -> :document_locked
      "DOCUMENT_LOCKED" -> :document_locked

      # Connection errors
      "ConnectionFailed" -> :connection_failed
      "CONNECTION_FAILED" -> :connection_failed
      "ConnectionTimeout" -> :connection_timeout
      "CONNECTION_TIMEOUT" -> :connection_timeout
      "NetworkError" -> :network_error
      "NETWORK_ERROR" -> :network_error
      "CannotConnect" -> :cannot_connect
      "CANNOT_CONNECT" -> :cannot_connect

      # Authentication errors
      "AuthenticationFailed" -> :authentication_failed
      "AUTHENTICATION_FAILED" -> :authentication_failed
      "InvalidCredentials" -> :invalid_credentials
      "INVALID_CREDENTIALS" -> :invalid_credentials

      # Timeout errors
      "Timeout" -> :timeout
      "TIMEOUT" -> :timeout
      "DurabilityTimeout" -> :durability_timeout
      "DURABILITY_TIMEOUT" -> :durability_timeout

      # Server errors
      "ServerError" -> :server_error
      "SERVER_ERROR" -> :server_error
      "TemporaryFailure" -> :temporary_failure
      "TEMPORARY_FAILURE" -> :temporary_failure
      "OutOfMemory" -> :out_of_memory
      "OUT_OF_MEMORY" -> :out_of_memory
      "NotSupported" -> :not_supported
      "NOT_SUPPORTED" -> :not_supported
      "InternalError" -> :internal_error
      "INTERNAL_ERROR" -> :internal_error

      # Bucket/Scope/Collection errors
      "BucketNotFound" -> :bucket_not_found
      "BUCKET_NOT_FOUND" -> :bucket_not_found
      "ScopeNotFound" -> :scope_not_found
      "SCOPE_NOT_FOUND" -> :scope_not_found
      "CollectionNotFound" -> :collection_not_found
      "COLLECTION_NOT_FOUND" -> :collection_not_found

      # Query errors
      "QueryError" -> :query_error
      "QUERY_ERROR" -> :query_error
      "PlanningFailure" -> :planning_failure
      "PLANNING_FAILURE" -> :planning_failure
      "IndexNotFound" -> :index_not_found
      "INDEX_NOT_FOUND" -> :index_not_found
      "PreparedStatementFailure" -> :prepared_statement_failure
      "PREPARED_STATEMENT_FAILURE" -> :prepared_statement_failure
      "PreparedStatementNotFound" -> :prepared_statement_not_found
      "PREPARED_STATEMENT_NOT_FOUND" -> :prepared_statement_not_found
      "QueryCancelled" -> :query_cancelled
      "QUERY_CANCELLED" -> :query_cancelled

      # Durability errors
      "DurabilityImpossible" -> :durability_impossible
      "DURABILITY_IMPOSSIBLE" -> :durability_impossible
      "DurabilityAmbiguous" -> :durability_ambiguous
      "DURABILITY_AMBIGUOUS" -> :durability_ambiguous
      "DurabilitySyncWriteInProgress" -> :durability_sync_write_in_progress
      "DURABILITY_SYNC_WRITE_IN_PROGRESS" -> :durability_sync_write_in_progress

      # Subdocument errors
      "SubdocPathNotFound" -> :subdoc_path_not_found
      "SUBDOC_PATH_NOT_FOUND" -> :subdoc_path_not_found
      "SubdocPathExists" -> :subdoc_path_exists
      "SUBDOC_PATH_EXISTS" -> :subdoc_path_exists
      "SubdocPathMismatch" -> :subdoc_path_mismatch
      "SUBDOC_PATH_MISMATCH" -> :subdoc_path_mismatch
      "SubdocPathInvalid" -> :subdoc_path_invalid
      "SUBDOC_PATH_INVALID" -> :subdoc_path_invalid
      "SubdocValueTooDeep" -> :subdoc_value_too_deep
      "SUBDOC_VALUE_TOO_DEEP" -> :subdoc_value_too_deep

      # Encoding errors
      "EncodingError" -> :encoding_error
      "ENCODING_ERROR" -> :encoding_error
      "DecodingError" -> :decoding_error
      "DECODING_ERROR" -> :decoding_error
      "InvalidArgument" -> :invalid_argument
      "INVALID_ARGUMENT" -> :invalid_argument

      # Transaction errors
      "TransactionNotActive" -> :transaction_not_active
      "TRANSACTION_NOT_ACTIVE" -> :transaction_not_active
      "TransactionFailed" -> :transaction_failed
      "TRANSACTION_FAILED" -> :transaction_failed
      "TransactionTimeout" -> :transaction_timeout
      "TRANSACTION_TIMEOUT" -> :transaction_timeout
      "TransactionConflict" -> :transaction_conflict
      "TRANSACTION_CONFLICT" -> :transaction_conflict
      "TransactionRollbackFailed" -> :transaction_rollback_failed
      "TRANSACTION_ROLLBACK_FAILED" -> :transaction_rollback_failed

      # Generic errors
      "GenericError" -> :generic_error
      "GENERIC_ERROR" -> :generic_error
      "Unknown" -> :unknown_error
      "UNKNOWN" -> :unknown_error

      # Legacy error codes (for backward compatibility)
      "COMMUNICATION_FAILED" -> :communication_failed
      "INVALID_RESPONSE" -> :invalid_response
      "OPERATION_FAILED" -> :operation_failed
      "QUERY_FAILED" -> :query_error
      "SUBDOCUMENT_FAILED" -> :subdoc_path_not_found
      "PING_FAILED" -> :operation_failed
      "DIAGNOSTICS_FAILED" -> :operation_failed

      _ -> :unknown_error
    end
  end

  @doc """
  Gets a human-readable error message for the given reason.

  ## Parameters

  - `reason` - Error reason

  ## Returns

  - `String.t()` - Human-readable error message

  ## Examples

      Error.message_for_reason(:document_not_found)  # "Document not found"
      Error.message_for_reason(:connection_failed)   # "Connection failed"

  """
  @spec message_for_reason(atom()) :: String.t()
  def message_for_reason(reason) do
    case reason do
      # Document errors
      :document_not_found -> "Document not found"
      :document_exists -> "Document already exists"
      :document_locked -> "Document is locked"

      # Connection errors
      :connection_failed -> "Connection to cluster failed"
      :connection_timeout -> "Connection timed out"
      :network_error -> "Network error occurred"
      :cannot_connect -> "Cannot connect to cluster"

      # Authentication errors
      :authentication_failed -> "Authentication failed"
      :invalid_credentials -> "Invalid credentials provided"

      # Timeout errors
      :timeout -> "Operation timed out"
      :durability_timeout -> "Durability operation timed out"

      # Server errors
      :server_error -> "Server error occurred"
      :temporary_failure -> "Temporary failure occurred"
      :out_of_memory -> "Server out of memory"
      :not_supported -> "Operation not supported"
      :internal_error -> "Internal server error"

      # Bucket/Scope/Collection errors
      :bucket_not_found -> "Bucket not found"
      :scope_not_found -> "Scope not found"
      :collection_not_found -> "Collection not found"

      # Query errors
      :query_error -> "N1QL query failed"
      :planning_failure -> "Query planning failed"
      :index_not_found -> "Index not found"
      :prepared_statement_failure -> "Prepared statement failed"
      :prepared_statement_not_found -> "Prepared statement not found"
      :query_cancelled -> "Query was cancelled"

      # Durability errors
      :durability_impossible -> "Durability level impossible"
      :durability_ambiguous -> "Durability level ambiguous"
      :durability_sync_write_in_progress -> "Durability sync write in progress"

      # Subdocument errors
      :subdoc_path_not_found -> "Subdocument path not found"
      :subdoc_path_exists -> "Subdocument path already exists"
      :subdoc_path_mismatch -> "Subdocument path type mismatch"
      :subdoc_path_invalid -> "Subdocument path invalid"
      :subdoc_value_too_deep -> "Subdocument value too deep"

      # Encoding errors
      :encoding_error -> "Encoding error occurred"
      :decoding_error -> "Decoding error occurred"
      :invalid_argument -> "Invalid argument provided"

      # Transaction errors
      :transaction_not_active -> "Transaction not active"
      :transaction_failed -> "Transaction failed"
      :transaction_timeout -> "Transaction timed out"
      :transaction_conflict -> "Transaction conflict occurred"
      :transaction_rollback_failed -> "Transaction rollback failed"

      # Generic errors
      :generic_error -> "Generic error occurred"
      :unknown_error -> "Unknown error occurred"

      # Legacy errors
      :communication_failed -> "Communication with Zig port failed"
      :invalid_response -> "Invalid response from Zig port"
      :operation_failed -> "Operation failed"

      _ -> "Unexpected error occurred"
    end
  end

  @doc """
  Checks if the error is retryable.

  ## Parameters

  - `error` - The error to check

  ## Returns

  - `boolean()` - Whether the error is retryable

  ## Examples

      Error.retryable?(%Error{reason: :timeout})  # true
      Error.retryable?(%Error{reason: :document_not_found})  # false

  """
  @spec retryable?(t()) :: boolean()
  def retryable?(%__MODULE__{reason: reason}) do
    case reason do
      # Timeout errors are retryable
      :timeout -> true
      :connection_timeout -> true
      :durability_timeout -> true

      # Temporary failures are retryable
      :temporary_failure -> true

      # Connection errors are retryable
      :connection_failed -> true
      :network_error -> true
      :communication_failed -> true

      # Durability ambiguous is retryable (may have succeeded)
      :durability_ambiguous -> true

      # Server temporary errors are retryable
      :server_error -> true
      :out_of_memory -> true

      # Document locked is retryable (may become available)
      :document_locked -> true

      # All other errors are not retryable
      _ -> false
    end
  end

  @doc """
  Gets the recommended retry delay in milliseconds.

  ## Parameters

  - `error` - The error to check
  - `attempt` - Current retry attempt (default: 1)

  ## Returns

  - `non_neg_integer()` - Retry delay in milliseconds

  ## Examples

      Error.retry_delay(%Error{reason: :timeout}, 1)  # 1000
      Error.retry_delay(%Error{reason: :timeout}, 3)  # 4000

  """
  @spec retry_delay(t(), non_neg_integer()) :: non_neg_integer()
  def retry_delay(%__MODULE__{reason: reason}, attempt \\ 1) do
    base_delay =
      case reason do
        # Timeout errors - moderate delay
        :timeout -> 1000
        :connection_timeout -> 2000
        :durability_timeout -> 1500

        # Temporary failures - short delay
        :temporary_failure -> 500

        # Connection errors - longer delay
        :connection_failed -> 2000
        :network_error -> 1500
        :communication_failed -> 1000

        # Durability errors - short delay
        :durability_ambiguous -> 500

        # Server errors - moderate delay
        :server_error -> 1000
        :out_of_memory -> 2000

        # Document locked - short delay
        :document_locked -> 300

        # Default
        _ -> 1000
      end

    # Exponential backoff with jitter (max 30 seconds)
    delay = min(base_delay * :math.pow(2, attempt - 1), 30_000)
    jitter = :rand.uniform() * 0.1 * delay
    trunc(delay + jitter)
  end

  @doc """
  Converts the error to a map for serialization.

  ## Parameters

  - `error` - The error to convert

  ## Returns

  - `map()` - Error as a map

  ## Examples

      Error.to_map(%Error{reason: :timeout, message: "Operation timed out"})
      # %{"reason" => "timeout", "message" => "Operation timed out", "details" => nil}

  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{reason: reason, message: message, details: details}) do
    %{
      "reason" => Atom.to_string(reason),
      "message" => message,
      "details" => details
    }
  end

  # Exception callbacks

  @impl true
  def exception(attrs) do
    struct(__MODULE__, attrs)
  end

  @impl true
  def message(%__MODULE__{message: message, details: nil}) do
    message
  end

  @impl true
  def message(%__MODULE__{message: message, details: details}) do
    "#{message} (Details: #{inspect(details)})"
  end
end

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
  def from_map(error_map) do
    reason =
      error_map
      |> Map.get("code", "UNKNOWN_ERROR")
      |> zig_to_elixir_reason()

    message = Map.get(error_map, "message", "Unknown error occurred")
    details = Map.get(error_map, "details", %{})

    new(reason, message, details)
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
      "DOCUMENT_NOT_FOUND" -> :document_not_found
      "DOCUMENT_EXISTS" -> :document_exists
      "DOCUMENT_LOCKED" -> :document_locked
      "TIMEOUT" -> :timeout
      "AUTHENTICATION_FAILED" -> :authentication_failed
      "BUCKET_NOT_FOUND" -> :bucket_not_found
      "TEMPORARY_FAILURE" -> :temporary_failure
      "DURABILITY_AMBIGUOUS" -> :durability_ambiguous
      "INVALID_ARGUMENT" -> :invalid_argument
      "CONNECTION_FAILED" -> :connection_failed
      "COMMUNICATION_FAILED" -> :communication_failed
      "INVALID_RESPONSE" -> :invalid_response
      "OPERATION_FAILED" -> :operation_failed
      "QUERY_FAILED" -> :query_failed
      "SUBDOCUMENT_FAILED" -> :subdocument_failed
      "PING_FAILED" -> :ping_failed
      "DIAGNOSTICS_FAILED" -> :diagnostics_failed
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
      :document_not_found -> "Document not found"
      :document_exists -> "Document already exists"
      :document_locked -> "Document is locked"
      :timeout -> "Operation timed out"
      :authentication_failed -> "Authentication failed"
      :bucket_not_found -> "Bucket not found"
      :temporary_failure -> "Temporary failure occurred"
      :durability_ambiguous -> "Durability level ambiguous"
      :invalid_argument -> "Invalid argument provided"
      :connection_failed -> "Connection to cluster failed"
      :communication_failed -> "Communication with Zig port failed"
      :invalid_response -> "Invalid response from Zig port"
      :operation_failed -> "Operation failed"
      :query_failed -> "N1QL query failed"
      :subdocument_failed -> "Subdocument operation failed"
      :ping_failed -> "Ping operation failed"
      :diagnostics_failed -> "Diagnostics operation failed"
      :unknown_error -> "Unknown error occurred"
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
      :timeout -> true
      :temporary_failure -> true
      :connection_failed -> true
      :communication_failed -> true
      :durability_ambiguous -> true
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
        :timeout -> 1000
        :temporary_failure -> 500
        :connection_failed -> 2000
        :communication_failed -> 1000
        :durability_ambiguous -> 500
        _ -> 1000
      end

    # Exponential backoff with jitter
    delay = base_delay * :math.pow(2, attempt - 1)
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

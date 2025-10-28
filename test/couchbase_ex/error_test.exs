defmodule CouchbaseEx.ErrorTest do
  use ExUnit.Case, async: true

  alias CouchbaseEx.Error

  doctest CouchbaseEx.Error

  describe "Error.new/3" do
    test "creates error with reason and message" do
      error = Error.new(:document_not_found, "Document not found")

      assert %Error{} = error
      assert error.reason == :document_not_found
      assert error.message == "Document not found"
      assert error.details == nil
    end

    test "creates error with details" do
      details = %{key: "user:123", bucket: "default"}
      error = Error.new(:document_not_found, "Document not found", details)

      assert error.details == details
    end
  end

  describe "Error.from_map/1" do
    test "creates error from structured map" do
      error_map = %{
        "code" => "DocumentNotFound",
        "message" => "Document not found in bucket",
        "details" => %{"key" => "user:123"}
      }

      error = Error.from_map(error_map)

      assert error.reason == :document_not_found
      assert error.message == "Document not found in bucket"
      assert error.details == %{"key" => "user:123"}
    end

    test "handles uppercase error codes" do
      error_map = %{"code" => "DOCUMENT_NOT_FOUND", "message" => "Not found"}
      error = Error.from_map(error_map)

      assert error.reason == :document_not_found
    end

    test "handles unknown error codes" do
      error_map = %{"code" => "UNKNOWN_CODE", "message" => "Some error"}
      error = Error.from_map(error_map)

      assert error.reason == :unknown_error
    end
  end

  describe "Error.from_response/1" do
    test "parses structured error response" do
      response = %{
        "success" => false,
        "data" => %{
          "code" => "DocumentNotFound",
          "message" => "Document not found"
        },
        "error" => "DocumentNotFound: user:123"
      }

      error = Error.from_response(response)

      assert error.reason == :document_not_found
      assert error.message == "Document not found"
    end

    test "parses simple error message" do
      response = %{"error" => "ConnectionFailed: timeout"}
      error = Error.from_response(response)

      assert error.reason == :connection_failed
      assert error.details == %{context: "timeout"}
    end

    test "handles plain string errors" do
      error = Error.from_response("Timeout")

      assert error.reason == :timeout
    end

    test "handles unknown response format" do
      error = Error.from_response(%{})

      assert error.reason == :unknown_error
    end
  end

  describe "Error.parse_error_message/1" do
    test "extracts error code and context" do
      error = Error.parse_error_message("DocumentNotFound: user:123")

      assert error.reason == :document_not_found
      assert error.details == %{context: "user:123"}
    end

    test "handles error without context" do
      error = Error.parse_error_message("Timeout")

      assert error.reason == :timeout
      assert error.message == "Timeout"
    end
  end

  describe "Error.zig_to_elixir_reason/1" do
    test "converts document errors" do
      assert Error.zig_to_elixir_reason("DocumentNotFound") == :document_not_found
      assert Error.zig_to_elixir_reason("DocumentExists") == :document_exists
      assert Error.zig_to_elixir_reason("DocumentLocked") == :document_locked
    end

    test "converts connection errors" do
      assert Error.zig_to_elixir_reason("ConnectionFailed") == :connection_failed
      assert Error.zig_to_elixir_reason("ConnectionTimeout") == :connection_timeout
      assert Error.zig_to_elixir_reason("NetworkError") == :network_error
    end

    test "converts authentication errors" do
      assert Error.zig_to_elixir_reason("AuthenticationFailed") == :authentication_failed
      assert Error.zig_to_elixir_reason("InvalidCredentials") == :invalid_credentials
    end

    test "converts timeout errors" do
      assert Error.zig_to_elixir_reason("Timeout") == :timeout
      assert Error.zig_to_elixir_reason("DurabilityTimeout") == :durability_timeout
    end

    test "converts server errors" do
      assert Error.zig_to_elixir_reason("ServerError") == :server_error
      assert Error.zig_to_elixir_reason("TemporaryFailure") == :temporary_failure
      assert Error.zig_to_elixir_reason("OutOfMemory") == :out_of_memory
    end

    test "converts query errors" do
      assert Error.zig_to_elixir_reason("QueryError") == :query_error
      assert Error.zig_to_elixir_reason("PlanningFailure") == :planning_failure
      assert Error.zig_to_elixir_reason("IndexNotFound") == :index_not_found
    end

    test "converts subdocument errors" do
      assert Error.zig_to_elixir_reason("SubdocPathNotFound") == :subdoc_path_not_found
      assert Error.zig_to_elixir_reason("SubdocPathExists") == :subdoc_path_exists
      assert Error.zig_to_elixir_reason("SubdocPathInvalid") == :subdoc_path_invalid
    end

    test "converts durability errors" do
      assert Error.zig_to_elixir_reason("DurabilityImpossible") == :durability_impossible
      assert Error.zig_to_elixir_reason("DurabilityAmbiguous") == :durability_ambiguous
    end

    test "handles uppercase legacy codes" do
      assert Error.zig_to_elixir_reason("DOCUMENT_NOT_FOUND") == :document_not_found
      assert Error.zig_to_elixir_reason("CONNECTION_FAILED") == :connection_failed
    end

    test "returns unknown_error for unrecognized codes" do
      assert Error.zig_to_elixir_reason("UnknownCode") == :unknown_error
    end
  end

  describe "Error.message_for_reason/1" do
    test "returns message for document errors" do
      assert Error.message_for_reason(:document_not_found) == "Document not found"
      assert Error.message_for_reason(:document_exists) == "Document already exists"
    end

    test "returns message for connection errors" do
      assert Error.message_for_reason(:connection_failed) == "Connection to cluster failed"
      assert Error.message_for_reason(:network_error) == "Network error occurred"
    end

    test "returns message for timeout errors" do
      assert Error.message_for_reason(:timeout) == "Operation timed out"
    end

    test "returns message for query errors" do
      assert Error.message_for_reason(:query_error) == "N1QL query failed"
    end

    test "returns message for subdocument errors" do
      assert Error.message_for_reason(:subdoc_path_not_found) == "Subdocument path not found"
    end

    test "returns default message for unknown reason" do
      assert Error.message_for_reason(:some_unknown_reason) == "Unexpected error occurred"
    end
  end

  describe "Error.retryable?/1" do
    test "timeout errors are retryable" do
      assert Error.retryable?(%Error{reason: :timeout})
      assert Error.retryable?(%Error{reason: :connection_timeout})
      assert Error.retryable?(%Error{reason: :durability_timeout})
    end

    test "temporary failures are retryable" do
      assert Error.retryable?(%Error{reason: :temporary_failure})
    end

    test "connection errors are retryable" do
      assert Error.retryable?(%Error{reason: :connection_failed})
      assert Error.retryable?(%Error{reason: :network_error})
    end

    test "document locked is retryable" do
      assert Error.retryable?(%Error{reason: :document_locked})
    end

    test "document not found is not retryable" do
      refute Error.retryable?(%Error{reason: :document_not_found})
    end

    test "authentication errors are not retryable" do
      refute Error.retryable?(%Error{reason: :authentication_failed})
    end

    test "invalid argument is not retryable" do
      refute Error.retryable?(%Error{reason: :invalid_argument})
    end
  end

  describe "Error.retry_delay/2" do
    test "returns base delay for first attempt" do
      error = %Error{reason: :timeout}
      delay = Error.retry_delay(error, 1)

      # Should be around 1000ms (base) with jitter
      assert delay >= 900 and delay <= 1200
    end

    test "increases delay exponentially" do
      error = %Error{reason: :timeout}
      delay1 = Error.retry_delay(error, 1)
      delay2 = Error.retry_delay(error, 2)
      delay3 = Error.retry_delay(error, 3)

      # Each delay should be roughly double the previous (with jitter)
      assert delay2 > delay1
      assert delay3 > delay2
    end

    test "caps delay at 30 seconds" do
      error = %Error{reason: :timeout}
      delay = Error.retry_delay(error, 10)

      # Should not exceed 30 seconds (with small jitter allowance)
      assert delay <= 33_000
    end

    test "uses different base delays for different errors" do
      timeout_delay = Error.retry_delay(%Error{reason: :timeout}, 1)
      temp_failure_delay = Error.retry_delay(%Error{reason: :temporary_failure}, 1)
      connection_delay = Error.retry_delay(%Error{reason: :connection_failed}, 1)

      # Temporary failure should have shortest delay
      assert temp_failure_delay < timeout_delay
      # Connection failure should have longest delay
      assert connection_delay > timeout_delay
    end

    test "document locked has short delay" do
      delay = Error.retry_delay(%Error{reason: :document_locked}, 1)

      # Should be around 300ms
      assert delay >= 270 and delay <= 400
    end
  end

  describe "Error.to_map/1" do
    test "converts error to map" do
      error = Error.new(:document_not_found, "Not found", %{key: "user:123"})
      map = Error.to_map(error)

      assert map["reason"] == "document_not_found"
      assert map["message"] == "Not found"
      assert map["details"] == %{key: "user:123"}
    end

    test "handles nil details" do
      error = Error.new(:timeout, "Timed out")
      map = Error.to_map(error)

      assert map["details"] == nil
    end
  end

  describe "Exception behavior" do
    test "can be raised as exception" do
      assert_raise Error, "Document not found", fn ->
        raise Error, reason: :document_not_found, message: "Document not found"
      end
    end

    test "formats message with details" do
      error = Error.new(:document_not_found, "Not found", %{key: "user:123"})
      message = Exception.message(error)

      assert message =~ "Not found"
      assert message =~ "user:123"
    end

    test "formats message without details" do
      error = Error.new(:timeout, "Operation timed out")
      message = Exception.message(error)

      assert message == "Operation timed out"
    end
  end
end

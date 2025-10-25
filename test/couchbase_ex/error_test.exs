defmodule CouchbaseEx.ErrorTest do
  use ExUnit.Case, async: true

  alias CouchbaseEx.Error

  describe "Error.new/3" do
    test "creates error with reason and message" do
      error = Error.new(:timeout, "Operation timed out")

      assert error.reason == :timeout
      assert error.message == "Operation timed out"
      assert error.details == nil
    end

    test "creates error with details" do
      details = %{key: "user:123", timeout: 5000}
      error = Error.new(:timeout, "Operation timed out", details)

      assert error.reason == :timeout
      assert error.message == "Operation timed out"
      assert error.details == details
    end
  end

  describe "Error.from_map/1" do
    test "creates error from map" do
      error_map = %{
        "code" => "DOCUMENT_NOT_FOUND",
        "message" => "Document not found",
        "details" => %{"key" => "user:123"}
      }

      error = Error.from_map(error_map)

      assert error.reason == :document_not_found
      assert error.message == "Document not found"
      assert error.details == %{"key" => "user:123"}
    end

    test "handles missing fields" do
      error_map = %{"code" => "UNKNOWN_ERROR"}
      error = Error.from_map(error_map)

      assert error.reason == :unknown_error
      assert error.message == "Unknown error occurred"
      assert error.details == %{}
    end
  end

  describe "Error.zig_to_elixir_reason/1" do
    test "converts Zig error codes to Elixir reasons" do
      assert Error.zig_to_elixir_reason("DOCUMENT_NOT_FOUND") == :document_not_found
      assert Error.zig_to_elixir_reason("DOCUMENT_EXISTS") == :document_exists
      assert Error.zig_to_elixir_reason("TIMEOUT") == :timeout
      assert Error.zig_to_elixir_reason("CONNECTION_FAILED") == :connection_failed
      assert Error.zig_to_elixir_reason("UNKNOWN_ERROR") == :unknown_error
    end
  end

  describe "Error.message_for_reason/1" do
    test "returns human-readable messages" do
      assert Error.message_for_reason(:document_not_found) == "Document not found"
      assert Error.message_for_reason(:timeout) == "Operation timed out"
      assert Error.message_for_reason(:connection_failed) == "Connection to cluster failed"
      assert Error.message_for_reason(:unknown_error) == "Unknown error occurred"
    end
  end

  describe "Error.retryable?/1" do
    test "identifies retryable errors" do
      assert Error.retryable?(%Error{reason: :timeout}) == true
      assert Error.retryable?(%Error{reason: :temporary_failure}) == true
      assert Error.retryable?(%Error{reason: :connection_failed}) == true
      assert Error.retryable?(%Error{reason: :durability_ambiguous}) == true
    end

    test "identifies non-retryable errors" do
      assert Error.retryable?(%Error{reason: :document_not_found}) == false
      assert Error.retryable?(%Error{reason: :document_exists}) == false
      assert Error.retryable?(%Error{reason: :authentication_failed}) == false
    end
  end

  describe "Error.retry_delay/2" do
    test "calculates retry delay with exponential backoff" do
      error = %Error{reason: :timeout}

      delay1 = Error.retry_delay(error, 1)
      delay2 = Error.retry_delay(error, 2)
      delay3 = Error.retry_delay(error, 3)

      assert delay1 > 0
      assert delay2 > delay1
      assert delay3 > delay2
    end

    test "handles different error types" do
      timeout_error = %Error{reason: :timeout}
      connection_error = %Error{reason: :connection_failed}

      timeout_delay = Error.retry_delay(timeout_error, 1)
      connection_delay = Error.retry_delay(connection_error, 1)

      assert timeout_delay > 0
      assert connection_delay > timeout_delay
    end
  end

  describe "Error.to_map/1" do
    test "converts error to map" do
      error = %Error{
        reason: :timeout,
        message: "Operation timed out",
        details: %{key: "user:123"}
      }

      error_map = Error.to_map(error)

      assert error_map["reason"] == "timeout"
      assert error_map["message"] == "Operation timed out"
      assert error_map["details"] == %{key: "user:123"}
    end
  end

  describe "Error message/1" do
    test "returns message without details" do
      error = %Error{message: "Operation timed out", details: nil}
      assert Error.message(error) == "Operation timed out"
    end

    test "returns message with details" do
      error = %Error{
        message: "Operation timed out",
        details: %{key: "user:123"}
      }

      message = Error.message(error)
      assert String.contains?(message, "Operation timed out")
      assert String.contains?(message, "Details:")
    end
  end
end

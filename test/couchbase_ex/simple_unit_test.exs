defmodule CouchbaseEx.SimpleUnitTest do
  use ExUnit.Case, async: true

  alias CouchbaseEx.{Error, Options, Config}

  describe "Error module" do
    test "creates error with reason and message" do
      error = Error.new(:timeout, "Operation timed out")

      assert error.reason == :timeout
      assert error.message == "Operation timed out"
      assert error.details == nil
    end

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

    test "identifies retryable errors" do
      assert Error.retryable?(%Error{reason: :timeout}) == true
      assert Error.retryable?(%Error{reason: :temporary_failure}) == true
      assert Error.retryable?(%Error{reason: :document_not_found}) == false
    end

    test "calculates retry delay" do
      error = %Error{reason: :timeout}

      delay1 = Error.retry_delay(error, 1)
      delay2 = Error.retry_delay(error, 2)

      assert delay1 > 0
      assert delay2 > delay1
    end
  end

  describe "Options module" do
    test "creates options with defaults" do
      options = Options.new()

      assert options.bucket == "default"
      assert options.timeout == 5000
      assert options.expiry == nil
      assert options.durability == :none
      assert options.params == []
      assert options.pool_size == 10
    end

    test "creates options with custom values" do
      opts = [
        bucket: "my_bucket",
        timeout: 10_000,
        expiry: 3_600,
        durability: :majority,
        params: ["param1", "param2"],
        pool_size: 20
      ]

      options = Options.new(opts)

      assert options.bucket == "my_bucket"
      assert options.timeout == 10_000
      assert options.expiry == 3_600
      assert options.durability == :majority
      assert options.params == ["param1", "param2"]
      assert options.pool_size == 20
    end

    test "validates valid options" do
      options = %Options{
        bucket: "my_bucket",
        timeout: 5_000,
        expiry: 3_600,
        durability: :majority,
        pool_size: 10
      }

      assert Options.validate_struct(options) == :ok
    end

    test "validates invalid options" do
      options = %Options{
        bucket: "",
        timeout: -1,
        expiry: -1,
        durability: :invalid,
        pool_size: 0
      }

      assert {:error, errors} = Options.validate_struct(options)
      refute Enum.empty?(errors)
    end

    test "merges options" do
      options1 = %Options{
        bucket: "bucket1",
        timeout: 5000,
        durability: :none
      }

      options2 = %Options{
        bucket: "bucket2",
        timeout: 10_000,
        durability: :majority
      }

      merged = Options.merge(options1, options2)

      assert merged.bucket == "bucket2"
      assert merged.timeout == 10_000
      assert merged.durability == :majority
    end
  end

  describe "Config module" do
    test "returns connection configuration" do
      config = Config.connection_config()

      assert is_map(config)
      assert Map.has_key?(config, :connection_string)
      assert Map.has_key?(config, :username)
      assert Map.has_key?(config, :password)
      assert Map.has_key?(config, :bucket)
      assert Map.has_key?(config, :timeout)
      assert Map.has_key?(config, :pool_size)
    end

    test "returns default values" do
      assert is_binary(Config.connection_string())
      assert is_binary(Config.username())
      assert is_binary(Config.password())
      assert is_binary(Config.bucket())
      assert is_integer(Config.timeout())
      assert is_integer(Config.pool_size())
    end

    test "validates configuration" do
      result = Config.validate()
      assert result == :ok or match?({:error, _}, result)
    end
  end

  describe "Client struct" do
    test "creates client struct" do
      client = %CouchbaseEx.Client{
        port: self(),
        connection_string: "couchbase://localhost",
        username: "admin",
        password: "password",
        bucket: "default",
        timeout: 5_000,
        pool_size: 10,
        ref_counter: :counters.new(1, [:atomics])
      }

      assert client.port == self()
      assert client.connection_string == "couchbase://localhost"
      assert client.username == "admin"
      assert client.password == "password"
      assert client.bucket == "default"
      assert client.timeout == 5_000
      assert client.pool_size == 10
    end
  end

  describe "Error handling" do
    test "handles not connected error" do
      mock_client = %CouchbaseEx.Client{port: nil}

      # This should return an error because the client is not connected
      assert {:error, %Error{reason: :not_connected}} =
               CouchbaseEx.get(mock_client, "key")
    end

    test "handles invalid client" do
      # Test with nil client - this will cause a KeyError when trying to access the port
      assert_raise KeyError, fn ->
        CouchbaseEx.get(nil, "key")
      end
    end
  end
end

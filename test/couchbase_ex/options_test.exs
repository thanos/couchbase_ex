defmodule CouchbaseEx.OptionsTest do
  use ExUnit.Case, async: true

  alias CouchbaseEx.Options

  describe "Options.new/1" do
    test "creates options with defaults" do
      {:ok, options} = Options.new()

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
        expiry: 3600,
        durability: :majority,
        params: ["param1", "param2"],
        pool_size: 20
      ]

      {:ok, options} = Options.new(opts)

      assert options.bucket == "my_bucket"
      assert options.timeout == 10_000
      assert options.expiry == 3_600
      assert options.durability == :majority
      assert options.params == ["param1", "param2"]
      assert options.pool_size == 20
    end
  end

  describe "Options.get_default_bucket/0" do
    test "returns default bucket" do
      # This test might be affected by environment variables
      bucket = Options.get_default_bucket()
      assert is_binary(bucket)
    end
  end

  describe "Options.get_default_connection_string/0" do
    test "returns default connection string" do
      connection_string = Options.get_default_connection_string()
      assert is_binary(connection_string)
    end
  end

  describe "Options.validate/1" do
    test "validates valid options" do
      options = %Options{
        bucket: "my_bucket",
        timeout: 5000,
        expiry: 3600,
        durability: :majority,
        params: [],
        pool_size: 10,
        connection_timeout: 10000,
        query_timeout: 30000,
        operation_timeout: 5000
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
      # Check that we get validation errors (nimble_options provides different messages)
      assert Enum.any?(errors, &String.contains?(&1, "timeout"))
    end
  end

  describe "Options.merge/2" do
    test "merges options with second taking precedence" do
      options1 = %Options{
        bucket: "bucket1",
        timeout: 5_000,
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

    test "merges options with nil values" do
      options1 = %Options{
        bucket: "bucket1",
        timeout: 5000,
        expiry: 3600
      }

      options2 = %Options{
        bucket: nil,
        timeout: nil,
        expiry: nil
      }

      merged = Options.merge(options1, options2)

      assert merged.bucket == "bucket1"
      assert merged.timeout == 5000
      assert merged.expiry == 3600
    end
  end

  describe "Options.to_map/1" do
    test "converts options to map" do
      options = %Options{
        bucket: "my_bucket",
        timeout: 5000,
        expiry: 3600,
        durability: :majority,
        params: ["param1"],
        pool_size: 10
      }

      options_map = Options.to_map(options)

      assert options_map["bucket"] == "my_bucket"
      assert options_map["timeout"] == 5000
      assert options_map["expiry"] == 3600
      assert options_map["durability"] == "majority"
      assert options_map["params"] == ["param1"]
      assert options_map["pool_size"] == 10
    end
  end

  describe "Options.from_map/1" do
    test "creates options from map" do
      options_map = %{
        "bucket" => "my_bucket",
        "timeout" => 5000,
        "expiry" => 3600,
        "durability" => "majority",
        "params" => ["param1"],
        "pool_size" => 10
      }

      options = Options.from_map(options_map)

      assert options.bucket == "my_bucket"
      assert options.timeout == 5000
      assert options.expiry == 3600
      assert options.durability == :majority
      assert options.params == ["param1"]
      assert options.pool_size == 10
    end

    test "creates options from map with defaults" do
      options_map = %{}

      options = Options.from_map(options_map)

      assert options.bucket == "default"
      assert options.timeout == 5000
      assert options.expiry == nil
      assert options.durability == :none
      assert options.params == []
      assert options.pool_size == 10
    end
  end
end

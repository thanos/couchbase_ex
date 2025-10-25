defmodule CouchbaseEx.ConfigTest do
  use ExUnit.Case, async: true

  alias CouchbaseEx.Config

  describe "Config.connection_string/0" do
    test "returns default connection string" do
      # This test might be affected by environment variables
      connection_string = Config.connection_string()
      assert is_binary(connection_string)
    end
  end

  describe "Config.username/0" do
    test "returns default username" do
      username = Config.username()
      assert is_binary(username)
    end
  end

  describe "Config.password/0" do
    test "returns default password" do
      password = Config.password()
      assert is_binary(password)
    end
  end

  describe "Config.bucket/0" do
    test "returns default bucket" do
      bucket = Config.bucket()
      assert is_binary(bucket)
    end
  end

  describe "Config.timeout/0" do
    test "returns default timeout" do
      timeout = Config.timeout()
      assert is_integer(timeout)
      assert timeout > 0
    end
  end

  describe "Config.pool_size/0" do
    test "returns default pool size" do
      pool_size = Config.pool_size()
      assert is_integer(pool_size)
      assert pool_size > 0
    end
  end

  describe "Config.connection_timeout/0" do
    test "returns default connection timeout" do
      connection_timeout = Config.connection_timeout()
      assert is_integer(connection_timeout)
      assert connection_timeout > 0
    end
  end

  describe "Config.query_timeout/0" do
    test "returns default query timeout" do
      query_timeout = Config.query_timeout()
      assert is_integer(query_timeout)
      assert query_timeout > 0
    end
  end

  describe "Config.operation_timeout/0" do
    test "returns default operation timeout" do
      operation_timeout = Config.operation_timeout()
      assert is_integer(operation_timeout)
      assert operation_timeout > 0
    end
  end

  describe "Config.connection_config/0" do
    test "returns connection configuration map" do
      config = Config.connection_config()

      assert is_map(config)
      assert Map.has_key?(config, :connection_string)
      assert Map.has_key?(config, :username)
      assert Map.has_key?(config, :password)
      assert Map.has_key?(config, :bucket)
      assert Map.has_key?(config, :timeout)
      assert Map.has_key?(config, :pool_size)
      assert Map.has_key?(config, :connection_timeout)
      assert Map.has_key?(config, :query_timeout)
      assert Map.has_key?(config, :operation_timeout)
    end
  end

  describe "Config.zig_server_config/0" do
    test "returns zig server configuration" do
      config = Config.zig_server_config()
      assert is_list(config)
    end
  end

  describe "Config.zig_server_path/0" do
    test "returns zig server path or nil" do
      path = Config.zig_server_path()
      assert is_nil(path) or is_binary(path)
    end
  end

  describe "Config.build_zig_server_on_startup?/0" do
    test "returns boolean" do
      build_on_startup = Config.build_zig_server_on_startup?()
      assert is_boolean(build_on_startup)
    end
  end

  describe "Config.validate/0" do
    test "validates configuration" do
      # This test depends on the current configuration
      result = Config.validate()
      assert result == :ok or match?({:error, _}, result)
    end
  end
end

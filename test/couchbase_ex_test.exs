defmodule CouchbaseExTest do
  use ExUnit.Case, async: true

  alias CouchbaseEx.Error

  doctest CouchbaseEx

  setup do
    # Setup test environment
    :ok
  end

  describe "CouchbaseEx.connect/4" do
    test "returns error for invalid connection" do
      # This test would require a running Couchbase server
      # For now, we'll test the error handling
      assert {:error, %Error{}} = CouchbaseEx.connect("invalid://connection", "user", "pass", [])
    end

    test "returns error for invalid connection with options" do
      opts = [bucket: "test_bucket", timeout: 10_000]

      assert {:error, %Error{}} =
               CouchbaseEx.connect("invalid://connection", "user", "pass", opts)
    end
  end

  describe "CouchbaseEx.get/2" do
    test "returns error when not connected" do
      # Create a mock client with nil port to simulate connection failure
      mock_client = %CouchbaseEx.Client{port: nil}
      assert {:error, %Error{}} = CouchbaseEx.get(mock_client, "key")
    end
  end

  describe "CouchbaseEx.set/3" do
    test "returns error when not connected" do
      mock_client = %CouchbaseEx.Client{port: nil}
      assert {:error, %Error{}} = CouchbaseEx.set(mock_client, "key", %{value: "test"})
    end
  end

  describe "CouchbaseEx.delete/2" do
    test "returns error when not connected" do
      mock_client = %CouchbaseEx.Client{port: nil}
      assert {:error, %Error{}} = CouchbaseEx.delete(mock_client, "key")
    end
  end

  describe "CouchbaseEx.query/2" do
    test "returns error when not connected" do
      mock_client = %CouchbaseEx.Client{port: nil}
      assert {:error, %Error{}} = CouchbaseEx.query(mock_client, "SELECT * FROM `default`")
    end
  end
end

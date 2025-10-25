defmodule CouchbaseExIntegrationTest do
  use ExUnit.Case, async: false

  alias CouchbaseEx.Error

  require Logger

  @moduletag :integration

  setup do
    # Skip integration tests if no Couchbase server is available
    case check_couchbase_availability() do
      :ok ->
        {:ok, %{}}

      {:error, reason} ->
        Logger.warning("Skipping integration tests: #{reason}")
        :skip
    end
  end

  describe "CouchbaseEx.connect/0" do
    test "connects using configuration" do
      {:ok, client} = CouchbaseEx.connect()
      assert %CouchbaseEx.Client{} = client
      CouchbaseEx.close(client)
    end

    test "connects with options override" do
      {:ok, client} = CouchbaseEx.connect(bucket: "default", timeout: 10_000)
      assert %CouchbaseEx.Client{} = client
      CouchbaseEx.close(client)
    end
  end

  describe "CouchbaseEx.connect/4" do
    test "connects with explicit parameters" do
      {:ok, client} =
        CouchbaseEx.connect("couchbase://localhost", "Administrator", "password", [])

      assert %CouchbaseEx.Client{} = client
      CouchbaseEx.close(client)
    end

    test "connects with explicit parameters and options" do
      {:ok, client} =
        CouchbaseEx.connect("couchbase://localhost", "Administrator", "password",
          bucket: "default",
          timeout: 10_000
        )

      assert %CouchbaseEx.Client{} = client
      CouchbaseEx.close(client)
    end
  end

  describe "CRUD Operations" do
    setup do
      {:ok, client} = CouchbaseEx.connect()
      on_exit(fn -> CouchbaseEx.close(client) end)
      {:ok, %{client: client}}
    end

    test "set and get document", %{client: client} do
      key = "test:integration:#{System.unique_integer([:positive])}"
      document = %{name: "Integration Test", value: 42, timestamp: System.system_time(:second)}

      # Set document
      assert :ok = CouchbaseEx.set(client, key, document)

      # Get document
      {:ok, retrieved} = CouchbaseEx.get(client, key)
      assert retrieved == document
    end

    test "insert new document", %{client: client} do
      key = "test:integration:insert:#{System.unique_integer([:positive])}"
      document = %{name: "Insert Test", value: 123}

      # Insert document
      assert :ok = CouchbaseEx.insert(client, key, document)

      # Verify document exists
      {:ok, retrieved} = CouchbaseEx.get(client, key)
      assert retrieved == document
    end

    test "replace existing document", %{client: client} do
      key = "test:integration:replace:#{System.unique_integer([:positive])}"
      original = %{name: "Original", value: 1}
      updated = %{name: "Updated", value: 2}

      # Insert original document
      assert :ok = CouchbaseEx.insert(client, key, original)

      # Replace document
      assert :ok = CouchbaseEx.replace(client, key, updated)

      # Verify document was replaced
      {:ok, retrieved} = CouchbaseEx.get(client, key)
      assert retrieved == updated
    end

    test "upsert document", %{client: client} do
      key = "test:integration:upsert:#{System.unique_integer([:positive])}"
      document = %{name: "Upsert Test", value: 456}

      # Upsert document
      assert :ok = CouchbaseEx.upsert(client, key, document)

      # Verify document exists
      {:ok, retrieved} = CouchbaseEx.get(client, key)
      assert retrieved == document
    end

    test "delete document", %{client: client} do
      key = "test:integration:delete:#{System.unique_integer([:positive])}"
      document = %{name: "Delete Test", value: 789}

      # Insert document
      assert :ok = CouchbaseEx.insert(client, key, document)

      # Verify document exists
      {:ok, retrieved} = CouchbaseEx.get(client, key)
      assert retrieved == document

      # Delete document
      assert :ok = CouchbaseEx.delete(client, key)

      # Verify document is deleted
      assert {:error, %Error{reason: :document_not_found}} = CouchbaseEx.get(client, key)
    end

    test "check document exists", %{client: client} do
      key = "test:integration:exists:#{System.unique_integer([:positive])}"
      document = %{name: "Exists Test", value: 999}

      # Document should not exist initially
      {:ok, false} = CouchbaseEx.exists(client, key)

      # Insert document
      assert :ok = CouchbaseEx.insert(client, key, document)

      # Document should exist now
      {:ok, true} = CouchbaseEx.exists(client, key)
    end
  end

  describe "N1QL Queries" do
    setup do
      {:ok, client} = CouchbaseEx.connect()
      on_exit(fn -> CouchbaseEx.close(client) end)
      {:ok, %{client: client}}
    end

    test "execute simple query", %{client: client} do
      # Insert test documents
      for i <- 1..3 do
        key = "test:query:#{i}"
        document = %{id: i, name: "Query Test #{i}", value: i * 10}
        CouchbaseEx.set(client, key, document)
      end

      # Execute query
      {:ok, results} =
        CouchbaseEx.query(client, "SELECT * FROM `default` WHERE id >= 1 AND id <= 3")

      assert is_list(results)
      assert length(results) >= 3
    end

    test "execute query with parameters", %{client: client} do
      # Insert test document
      key = "test:query:params"
      document = %{name: "Parameter Test", value: 42}
      CouchbaseEx.set(client, key, document)

      # Execute query with parameters
      {:ok, results} =
        CouchbaseEx.query(client, "SELECT * FROM `default` WHERE name = $1",
          params: ["Parameter Test"]
        )

      assert is_list(results)
      assert length(results) >= 1
    end
  end

  describe "Health and Diagnostics" do
    setup do
      {:ok, client} = CouchbaseEx.connect()
      on_exit(fn -> CouchbaseEx.close(client) end)
      {:ok, %{client: client}}
    end

    test "ping cluster", %{client: client} do
      {:ok, ping_result} = CouchbaseEx.ping(client)
      assert is_map(ping_result)
    end

    test "get diagnostics", %{client: client} do
      {:ok, diagnostics} = CouchbaseEx.diagnostics(client)
      assert is_map(diagnostics)
    end
  end

  # Private functions

  defp check_couchbase_availability do
    # Try to connect to Couchbase to check if it's available
    case CouchbaseEx.connect() do
      {:ok, client} ->
        CouchbaseEx.close(client)
        :ok

      {:error, %Error{reason: :connection_failed}} ->
        {:error, "Couchbase server not available"}

      {:error, %Error{reason: :server_exited}} ->
        {:error, "Zig server not available"}

      {:error, reason} ->
        {:error, "Connection failed: #{inspect(reason)}"}
    end
  end
end

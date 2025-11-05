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
        {:ok, %{skip: true}}
    end
  end

  describe "CouchbaseEx.connect/0" do
    test "connects using configuration", %{skip: skip} do
      if skip, do: :skip
      {:ok, client} = CouchbaseEx.connect()
      assert %CouchbaseEx.Client{} = client
      CouchbaseEx.close(client)
    end

    test "connects with options override", %{skip: skip} do
      if skip, do: :skip
      {:ok, client} = CouchbaseEx.connect(bucket: "default", timeout: 10_000)
      assert %CouchbaseEx.Client{} = client
      CouchbaseEx.close(client)
    end
  end

  describe "CouchbaseEx.connect/4" do
    test "connects with explicit parameters", %{skip: skip} do
      if skip, do: :skip

      # Get credentials from config (which loads from env vars)
      host = Application.get_env(:couchbase_ex, :connection_string)
      user = Application.get_env(:couchbase_ex, :username)
      pass = Application.get_env(:couchbase_ex, :password)

      {:ok, client} = CouchbaseEx.connect(host, user, pass, [])

      assert %CouchbaseEx.Client{} = client
      CouchbaseEx.close(client)
    end

    test "connects with explicit parameters and options", %{skip: skip} do
      if skip, do: :skip

      # Get credentials from config (which loads from env vars)
      host = Application.get_env(:couchbase_ex, :connection_string)
      user = Application.get_env(:couchbase_ex, :username)
      pass = Application.get_env(:couchbase_ex, :password)
      bucket = Application.get_env(:couchbase_ex, :bucket)

      {:ok, client} =
        CouchbaseEx.connect(host, user, pass,
          bucket: bucket,
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

  describe "Subdocument Operations" do
    setup do
      {:ok, client} = CouchbaseEx.connect()
      on_exit(fn -> CouchbaseEx.close(client) end)

      # Create a test document with nested structure
      test_doc = %{
        name: "John Doe",
        age: 30,
        email: "john@example.com",
        address: %{
          street: "123 Main St",
          city: "Springfield",
          zip: "12345"
        },
        hobbies: ["reading", "coding", "gaming"],
        metadata: %{
          created_at: "2024-01-01",
          updated_at: "2024-01-01"
        }
      }

      key = "subdoc_test:#{:erlang.unique_integer([:positive])}"
      {:ok, _} = CouchbaseEx.set(client, key, test_doc)

      {:ok, %{client: client, key: key}}
    end

    test "lookup_in - get single field", %{client: client, key: key} do
      specs = [%{op: "get", path: "name"}]
      {:ok, result} = CouchbaseEx.lookup_in(client, key, specs)

      assert is_map(result)
      assert Map.has_key?(result, "values")
      assert is_list(result["values"])
      assert length(result["values"]) == 1
    end

    test "lookup_in - get nested field", %{client: client, key: key} do
      specs = [%{op: "get", path: "address.city"}]
      {:ok, result} = CouchbaseEx.lookup_in(client, key, specs)

      assert is_map(result)
      assert Map.has_key?(result, "values")
      assert is_list(result["values"])
    end

    test "lookup_in - multiple fields", %{client: client, key: key} do
      specs = [
        %{op: "get", path: "name"},
        %{op: "get", path: "age"},
        %{op: "get", path: "email"}
      ]
      {:ok, result} = CouchbaseEx.lookup_in(client, key, specs)

      assert is_map(result)
      assert Map.has_key?(result, "values")
      assert is_list(result["values"])
      assert length(result["values"]) == 3
    end

    test "lookup_in - exists check", %{client: client, key: key} do
      specs = [%{op: "exists", path: "name"}]
      {:ok, result} = CouchbaseEx.lookup_in(client, key, specs)

      assert is_map(result)
      assert Map.has_key?(result, "cas")
    end

    test "mutate_in - upsert field", %{client: client, key: key} do
      specs = [%{op: "upsert", path: "name", value: "Jane Doe"}]
      {:ok, result} = CouchbaseEx.mutate_in(client, key, specs)

      assert is_map(result)
      assert Map.has_key?(result, "cas")

      # Verify the change
      lookup_specs = [%{op: "get", path: "name"}]
      {:ok, lookup_result} = CouchbaseEx.lookup_in(client, key, lookup_specs)
      assert is_list(lookup_result["values"])
    end

    test "mutate_in - replace field", %{client: client, key: key} do
      specs = [%{op: "replace", path: "age", value: "31"}]
      {:ok, result} = CouchbaseEx.mutate_in(client, key, specs)

      assert is_map(result)
      assert Map.has_key?(result, "cas")
    end

    test "mutate_in - remove field", %{client: client, key: key} do
      specs = [%{op: "remove", path: "email"}]
      {:ok, result} = CouchbaseEx.mutate_in(client, key, specs)

      assert is_map(result)
      assert Map.has_key?(result, "cas")
    end

    test "mutate_in - array operations", %{client: client, key: key} do
      specs = [%{op: "array_add_last", path: "hobbies", value: "\"swimming\""}]
      {:ok, result} = CouchbaseEx.mutate_in(client, key, specs)

      assert is_map(result)
      assert Map.has_key?(result, "cas")
    end

    test "mutate_in - counter operation", %{client: client, key: key} do
      specs = [%{op: "counter", path: "age", value: "1"}]
      {:ok, result} = CouchbaseEx.mutate_in(client, key, specs)

      assert is_map(result)
      assert Map.has_key?(result, "cas")
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

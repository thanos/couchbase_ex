defmodule CouchbaseEx.PortManager do
  @moduledoc """
  Manages communication with the Zig server process.

  This module handles the lifecycle of the Zig server process and provides
  a clean interface for sending commands and receiving responses.
  """

  use GenServer

  alias CouchbaseEx.{Error, Options}

  require Logger

  defstruct [
    :port,
    :connection_string,
    :username,
    :password,
    :options,
    :request_id,
    :pending_requests
  ]

  @type t :: %__MODULE__{
          port: port(),
          connection_string: String.t(),
          username: String.t(),
          password: String.t(),
          options: Options.t(),
          request_id: non_neg_integer(),
          pending_requests: map()
        }

  # Client API

  @doc """
  Starts the port manager process.

  ## Parameters

  - `connection_string` - Couchbase connection string
  - `username` - Username for authentication
  - `password` - Password for authentication
  - `options` - Connection options

  ## Returns

  - `{:ok, pid}` - Port manager started successfully
  - `{:error, reason}` - Failed to start port manager

  ## Examples

      {:ok, pid} = PortManager.start_link("couchbase://localhost", "admin", "password", options)

  """
  @spec start_link(String.t(), String.t(), String.t(), Options.t()) ::
          {:ok, pid()} | {:error, term()}
  def start_link(connection_string, username, password, options) do
    GenServer.start_link(__MODULE__, {
      connection_string,
      username,
      password,
      options
    })
  end

  @doc """
  Sends a command to the Zig server and waits for a response.

  ## Parameters

  - `pid` - Port manager process ID
  - `message` - Command message to send

  ## Returns

  - `{:ok, response}` - Command executed successfully
  - `{:error, reason}` - Command failed

  ## Examples

      PortManager.send_command(pid, %{command: "get", params: %{key: "user:123"}})

  """
  @spec send_command(pid(), map()) :: {:ok, any()} | {:error, term()}
  def send_command(pid, message) do
    GenServer.call(pid, {:send_command, message}, :infinity)
  end

  @doc """
  Stops the port manager process.

  ## Parameters

  - `pid` - Port manager process ID

  ## Examples

      PortManager.stop(pid)

  """
  @spec stop(pid()) :: :ok
  def stop(pid) do
    GenServer.stop(pid)
  end

  # Server callbacks

  @impl true
  def init({connection_string, username, password, options}) do
    case start_zig_server(connection_string, username, password, options) do
      {:ok, port} ->
        state = %__MODULE__{
          port: port,
          connection_string: connection_string,
          username: username,
          password: password,
          options: options,
          request_id: 0,
          pending_requests: %{}
        }

        Logger.info("CouchbaseEx PortManager started with Zig server")
        {:ok, state}

      {:error, reason} ->
        Logger.error("Failed to start Zig server: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:send_command, message}, from, state) do
    request_id = state.request_id + 1
    message_with_id = Map.put(message, "request_id", request_id)

    # Serialize message to JSON
    case Jason.encode(message_with_id) do
      {:ok, json_message} ->
        # Send command to Zig server
        Port.command(state.port, json_message <> "\n")

        # Store pending request
        new_pending_requests = Map.put(state.pending_requests, request_id, from)

        new_state = %{state | request_id: request_id, pending_requests: new_pending_requests}

        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Failed to encode message: #{inspect(reason)}")
        {:reply, {:error, Error.new(:serialization_failed, "Failed to encode message")}, state}
    end
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    # Parse response from Zig server
    case parse_response(data) do
      {:ok, response} ->
        request_id = Map.get(response, "request_id")

        case Map.get(state.pending_requests, request_id) do
          nil ->
            Logger.warning("Received response for unknown request ID: #{request_id}")
            {:noreply, state}

          from ->
            # Remove from pending requests
            new_pending_requests = Map.delete(state.pending_requests, request_id)
            new_state = %{state | pending_requests: new_pending_requests}

            # Send response back to caller
            GenServer.reply(from, {:ok, response})
            {:noreply, new_state}
        end

      {:error, reason} ->
        Logger.error("Failed to parse response: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    Logger.error("Zig server exited with status: #{status}")

    # Reply to all pending requests with error
    Enum.each(state.pending_requests, fn {_request_id, from} ->
      GenServer.reply(from, {:error, Error.new(:server_exited, "Zig server exited unexpectedly")})
    end)

    {:stop, :server_exited, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :port, port, reason}, %{port: port} = state) do
    Logger.error("Zig server port died: #{inspect(reason)}")

    # Reply to all pending requests with error
    Enum.each(state.pending_requests, fn {_request_id, from} ->
      GenServer.reply(from, {:error, Error.new(:port_died, "Zig server port died")})
    end)

    {:stop, :port_died, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("CouchbaseEx PortManager terminating: #{inspect(reason)}")

    # Close the port
    if state.port do
      Port.close(state.port)
    end

    # Reply to all pending requests with error
    Enum.each(state.pending_requests, fn {_request_id, from} ->
      GenServer.reply(from, {:error, Error.new(:server_terminated, "Server terminated")})
    end)

    :ok
  end

  # Private functions

  @spec start_zig_server(String.t(), String.t(), String.t(), Options.t()) ::
          {:ok, port()} | {:error, term()}
  defp start_zig_server(connection_string, username, password, options) do
    # Get the path to the Zig server executable
    zig_server_path = get_zig_server_path()

    # Check if the executable exists
    if File.exists?(zig_server_path) do
      # Prepare connection arguments for the Zig server
      connection_args = [
        "--connection-string",
        connection_string,
        "--username",
        username,
        "--password",
        password,
        "--bucket",
        options.bucket,
        "--timeout",
        to_string(options.timeout),
        "--pool-size",
        to_string(options.pool_size)
      ]

      # Start the Zig server process with connection arguments
      port =
        Port.open({:spawn_executable, zig_server_path}, [
          :binary,
          :exit_status,
          :stderr_to_stdout,
          {:args, connection_args}
        ])

      # Monitor the port
      _ref = Port.monitor(port)

      # Wait for the port to be ready
      case wait_for_port_ready(port, options.connection_timeout) do
        :ok ->
          {:ok, port}

        {:error, reason} ->
          Port.close(port)
          {:error, reason}
      end
    else
      {:error, "Zig server executable not found at #{zig_server_path}"}
    end
  end

  @spec get_zig_server_path() :: String.t()
  defp get_zig_server_path do
    # Try to find the Zig server executable
    case System.find_executable("couchbase_zig_server") do
      nil ->
        # Fallback to a relative path
        Path.join([Application.app_dir(:couchbase_ex, "priv"), "bin", "couchbase_zig_server"])

      path ->
        path
    end
  end

  @spec wait_for_port_ready(port(), non_neg_integer()) :: :ok | {:error, term()}
  defp wait_for_port_ready(port, timeout) do
    receive do
      {^port, {:data, "ready\n"}} ->
        :ok

      {^port, {:data, data}} ->
        Logger.debug("Zig server output: #{data}")
        wait_for_port_ready(port, timeout)

      {^port, {:exit_status, status}} ->
        {:error, "Zig server exited with status #{status}"}
    after
      timeout ->
        {:error, "Timeout waiting for Zig server to be ready"}
    end
  end

  @spec parse_response(String.t()) :: {:ok, map()} | {:error, term()}
  defp parse_response(data) do
    # Remove trailing newline
    clean_data = String.trim(data)

    case Jason.decode(clean_data) do
      {:ok, response} ->
        {:ok, response}

      {:error, reason} ->
        {:error, reason}
    end
  end
end

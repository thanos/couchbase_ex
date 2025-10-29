defmodule CouchbaseEx.ZigBuilder do
  @moduledoc """
  Builds the Zig server executable for CouchbaseEx.

  This module handles the compilation of the Zig server and provides
  utilities for checking if the server is available and building it.
  """

  require Logger

  @doc """
  Builds the Zig server executable.

  ## Returns

  - `{:ok, output}` - Build successful
  - `{:error, reason}` - Build failed

  ## Examples

      ZigBuilder.build_zig_server()
      # => {:ok, "Build successful"}

  """
  @spec build_zig_server() :: {:ok, String.t()} | {:error, String.t()}
  def build_zig_server do
    Logger.info("Building Zig server...")

    case System.cmd("zig", ["build"], cd: File.cwd!()) do
      {output, 0} ->
        Logger.info("Zig server built successfully")
        {:ok, output}
      {error, exit_code} ->
        error_msg = "Failed to build Zig server: #{error} (exit code: #{exit_code})"
        Logger.error(error_msg)
        {:error, error_msg}
    end
  end

  @doc """
  Gets the path to the built Zig server executable.

  ## Returns

  - `String.t()` - Path to the Zig server executable

  ## Examples

      ZigBuilder.zig_server_path()
      # => "/path/to/project/zig-out/bin/couchbase_zig_server"

  """
  @spec zig_server_path() :: String.t()
  def zig_server_path do
    Path.join([File.cwd!(), "zig-out", "bin", "couchbase_zig_server"])
  end

  @doc """
  Checks if the Zig server executable exists.

  ## Returns

  - `boolean()` - Whether the executable exists

  ## Examples

      ZigBuilder.zig_server_exists?()
      # => true

  """
  @spec zig_server_exists?() :: boolean()
  def zig_server_exists? do
    File.exists?(zig_server_path())
  end

  @doc """
  Ensures the Zig server is built and available.

  ## Returns

  - `{:ok, path}` - Server is available at the given path
  - `{:error, reason}` - Failed to build or find server

  ## Examples

      ZigBuilder.ensure_zig_server()
      # => {:ok, "/path/to/zig_server"}

  """
  @spec ensure_zig_server() :: {:ok, String.t()} | {:error, String.t()}
  def ensure_zig_server do
    if zig_server_exists?() do
      {:ok, zig_server_path()}
    else
      Logger.info("Zig server not found, building...")
      case build_zig_server() do
        {:ok, _} ->
          if zig_server_exists?() do
            {:ok, zig_server_path()}
          else
            {:error, "Zig server build completed but executable not found"}
          end
        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Cleans the Zig build artifacts.

  ## Returns

  - `{:ok, output}` - Clean successful
  - `{:error, reason}` - Clean failed

  ## Examples

      ZigBuilder.clean_zig_server()
      # => {:ok, "Clean successful"}

  """
  @spec clean_zig_server() :: {:ok, String.t()} | {:error, String.t()}
  def clean_zig_server do
    Logger.info("Cleaning Zig build artifacts...")

    # Remove the zig-out directory which contains all build artifacts
    zig_out_path = Path.join([File.cwd!(), "zig-out"])

    if File.exists?(zig_out_path) do
      case File.rm_rf(zig_out_path) do
        {:ok, _} ->
          Logger.info("Zig build artifacts cleaned")
          {:ok, "Removed #{zig_out_path}"}
        {:error, reason, _} ->
          error_msg = "Failed to remove zig-out directory: #{reason}"
          Logger.error(error_msg)
          {:error, error_msg}
      end
    else
      Logger.info("No zig-out directory found")
      {:ok, "No artifacts to clean"}
    end
  end

  @doc """
  Gets the version of the Zig compiler.

  ## Returns

  - `{:ok, version}` - Zig version
  - `{:error, reason}` - Failed to get version

  ## Examples

      ZigBuilder.zig_version()
      # => {:ok, "0.11.0"}

  """
  @spec zig_version() :: {:ok, String.t()} | {:error, String.t()}
  def zig_version do
    case System.cmd("zig", ["version"], cd: File.cwd!()) do
      {version, 0} ->
        {:ok, String.trim(version)}
      {error, exit_code} ->
        {:error, "Failed to get Zig version: #{error} (exit code: #{exit_code})"}
    end
  end

  @doc """
  Checks if Zig is installed and available.

  ## Returns

  - `boolean()` - Whether Zig is available

  ## Examples

      ZigBuilder.zig_available?()
      # => true

  """
  @spec zig_available?() :: boolean()
  def zig_available? do
    case System.cmd("zig", ["version"], cd: File.cwd!()) do
      {_, 0} -> true
      _ -> false
    end
  end

  @doc """
  Gets build information for debugging.

  ## Returns

  - `map()` - Build information

  ## Examples

      ZigBuilder.build_info()
      # => %{zig_available: true, server_exists: true, server_path: "/path/to/server"}

  """
  @spec build_info() :: map()
  def build_info do
    %{
      zig_available: zig_available?(),
      server_exists: zig_server_exists?(),
      server_path: zig_server_path(),
      zig_version: zig_version()
    }
  end
end

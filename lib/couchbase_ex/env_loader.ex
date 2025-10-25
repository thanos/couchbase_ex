defmodule CouchbaseEx.EnvLoader do
  @moduledoc """
  Environment variable loader using dotenvy.

  This module provides a centralized way to load environment variables
  from .env files with proper error handling.
  """

  @doc """
  Loads environment variables from .env files.

  ## Files loaded (in order):
  - .env
  - .env.{environment}
  - .env.{environment}.local

  ## Parameters
  - `environment` - The current environment (dev, test, prod)

  ## Returns
  - `:ok` - Successfully loaded
  - `{:error, reason}` - Failed to load

  ## Examples

      EnvLoader.load_env(:dev)
      EnvLoader.load_env(:test)
      EnvLoader.load_env(:prod)

  """
  @spec load_env(atom()) :: :ok | {:error, term()}
  def load_env(environment) do
    files = [
      ".env",
      ".env.#{environment}",
      ".env.#{environment}.local"
    ]

    try do
      Dotenvy.source(files, %{})
      :ok
    rescue
      error -> {:error, error}
    end
  end

  @doc """
  Loads environment variables from .env files with fallback.

  This function will attempt to load .env files but will not fail
  if they don't exist or can't be loaded.

  ## Parameters
  - `environment` - The current environment (dev, test, prod)

  ## Returns
  - `:ok` - Always returns :ok (errors are logged but not returned)

  ## Examples

      EnvLoader.load_env_safe(:dev)

  """
  @spec load_env_safe(atom()) :: :ok
  def load_env_safe(environment) do
    case load_env(environment) do
      :ok -> :ok
      {:error, reason} ->
        require Logger
        Logger.debug("Failed to load .env files: #{inspect(reason)}")
        :ok
    end
  end

  @doc """
  Loads environment variables at application startup.

  This function should be called during application startup to ensure
  .env files are loaded before configuration is accessed.

  ## Returns
  - `:ok` - Always returns :ok

  ## Examples

      EnvLoader.startup_load()

  """
  @spec startup_load() :: :ok
  def startup_load do
    environment = Application.get_env(:couchbase_ex, :environment, :dev)
    load_env_safe(environment)
  end
end

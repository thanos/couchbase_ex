defmodule Mix.Tasks.Zig.Clean do
  @moduledoc """
  Cleans the Zig build artifacts for CouchbaseEx.

  ## Examples

      mix zig.clean

  """
  use Mix.Task
  alias CouchbaseEx.ZigBuilder

  @shortdoc "Cleans the Zig build artifacts"

  @impl Mix.Task
  def run(_args) do
    case ZigBuilder.clean_zig_server() do
      {:ok, _} ->
        Mix.shell().info("✓ Zig build artifacts cleaned")
        :ok

      {:error, reason} ->
        Mix.shell().error("✗ Failed to clean Zig server: #{reason}")
        System.halt(1)
    end
  end
end

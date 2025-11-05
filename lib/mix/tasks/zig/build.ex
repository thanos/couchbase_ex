defmodule Mix.Tasks.Zig.Build do
  @moduledoc """
  Builds the Zig server executable for CouchbaseEx.

  ## Examples

      mix zig.build

  """
  use Mix.Task
  alias CouchbaseEx.ZigBuilder

  @shortdoc "Builds the Zig server executable"

  @impl Mix.Task
  def run(_args) do
    case ZigBuilder.build_zig_server() do
      {:ok, _} ->
        Mix.shell().info("✓ Zig server built successfully")
        :ok

      {:error, reason} ->
        Mix.shell().error("✗ Failed to build Zig server: #{reason}")
        System.halt(1)
    end
  end
end

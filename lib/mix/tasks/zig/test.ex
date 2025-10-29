defmodule Mix.Tasks.Zig.Test do
  @moduledoc """
  Runs the Zig server's test suite.

  ## Examples

      mix zig.test

  """
  use Mix.Task
  require Logger

  @shortdoc "Runs the Zig server tests"

  @impl Mix.Task
  def run(_args) do
    Logger.info("Running Zig server tests...")

    case System.cmd("zig", ["build", "test"], cd: File.cwd!()) do
      {output, 0} ->
        Mix.shell().info("✓ Zig tests passed")
        IO.puts(output)
        :ok

      {error, exit_code} ->
        Mix.shell().error("✗ Zig tests failed (exit code: #{exit_code})")
        IO.puts(error)
        System.halt(1)
    end
  end
end

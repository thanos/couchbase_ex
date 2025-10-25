defmodule CouchbaseEx.PortManagerBehaviour do
  @moduledoc """
  Behaviour for the PortManager to enable mocking in tests.
  """

  @callback start_link(String.t(), String.t(), String.t(), CouchbaseEx.Options.t()) ::
              {:ok, pid()} | {:error, term()}

  @callback send_command(pid(), map()) :: {:ok, any()} | {:error, term()}

  @callback stop(pid()) :: :ok
end

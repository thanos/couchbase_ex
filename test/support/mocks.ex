defmodule CouchbaseEx.Mocks do
  @moduledoc """
  Mock definitions for testing CouchbaseEx.
  """

  import Mox

  # Define mocks for the PortManager
  defmock(CouchbaseEx.PortManagerMock, for: CouchbaseEx.PortManagerBehaviour)

  # Define mocks for the Client
  defmock(CouchbaseEx.ClientMock, for: CouchbaseEx.ClientBehaviour)
end

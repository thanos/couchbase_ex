defmodule CouchbaseEx.ClientBehaviour do
  @moduledoc """
  Behaviour for the Client to enable mocking in tests.
  """

  @callback connect(String.t(), String.t(), String.t(), keyword()) ::
              {:ok, CouchbaseEx.Client.t()} | {:error, CouchbaseEx.Error.t()}

  @callback close(CouchbaseEx.Client.t()) :: :ok

  @callback get(CouchbaseEx.Client.t(), String.t(), keyword()) ::
              {:ok, any()} | {:error, CouchbaseEx.Error.t()}

  @callback set(CouchbaseEx.Client.t(), String.t(), any(), keyword()) ::
              {:ok, any()} | {:error, CouchbaseEx.Error.t()}

  @callback insert(CouchbaseEx.Client.t(), String.t(), any(), keyword()) ::
              {:ok, any()} | {:error, CouchbaseEx.Error.t()}

  @callback replace(CouchbaseEx.Client.t(), String.t(), any(), keyword()) ::
              {:ok, any()} | {:error, CouchbaseEx.Error.t()}

  @callback upsert(CouchbaseEx.Client.t(), String.t(), any(), keyword()) ::
              {:ok, any()} | {:error, CouchbaseEx.Error.t()}

  @callback delete(CouchbaseEx.Client.t(), String.t(), keyword()) ::
              {:ok, any()} | {:error, CouchbaseEx.Error.t()}

  @callback exists(CouchbaseEx.Client.t(), String.t(), keyword()) ::
              {:ok, boolean()} | {:error, CouchbaseEx.Error.t()}

  @callback query(CouchbaseEx.Client.t(), String.t(), keyword()) ::
              {:ok, list()} | {:error, CouchbaseEx.Error.t()}

  @callback lookup_in(CouchbaseEx.Client.t(), String.t(), list(), keyword()) ::
              {:ok, list()} | {:error, CouchbaseEx.Error.t()}

  @callback mutate_in(CouchbaseEx.Client.t(), String.t(), list(), keyword()) ::
              {:ok, list()} | {:error, CouchbaseEx.Error.t()}

  @callback ping(CouchbaseEx.Client.t(), keyword()) ::
              {:ok, map()} | {:error, CouchbaseEx.Error.t()}

  @callback diagnostics(CouchbaseEx.Client.t(), keyword()) ::
              {:ok, map()} | {:error, CouchbaseEx.Error.t()}
end

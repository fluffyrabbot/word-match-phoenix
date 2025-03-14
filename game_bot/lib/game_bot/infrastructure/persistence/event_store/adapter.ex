defmodule GameBot.Infrastructure.Persistence.EventStore.Adapter do
  @moduledoc """
  Adapter module providing a facade for EventStore operations.
  This module delegates to the configured implementation, which may be
  different in test and production environments.
  """

  alias GameBot.Infrastructure.Error

  # Get the configured adapter at runtime to allow for test overrides
  @fallback_adapter GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres

  @doc """
  Appends events to a stream.

  ## Parameters
  - `stream_id`: Unique identifier for the event stream
  - `expected_version`: Expected version of the stream for optimistic concurrency
  - `events`: List of events to append
  - `opts`: Options for the operation (e.g., timeout)

  ## Returns
  - `{:ok, new_version}` on success
  - `{:error, reason}` on failure
  """
  def append_to_stream(stream_id, expected_version, events, opts \\ []) do
    with {:ok, adapter} <- get_adapter() do
      adapter.append_to_stream(stream_id, expected_version, events, opts)
    end
  end

  @doc """
  Reads events from a stream in forward order.

  ## Parameters
  - `stream_id`: Identifier of the stream to read
  - `start_version`: Version to start reading from
  - `count`: Maximum number of events to read
  - `opts`: Options for the operation

  ## Returns
  - `{:ok, events}` on success
  - `{:error, reason}` on failure
  """
  def read_stream_forward(stream_id, start_version \\ 0, count \\ 1000, opts \\ []) do
    with {:ok, adapter} <- get_adapter() do
      adapter.read_stream_forward(stream_id, start_version, count, opts)
    end
  end

  @doc """
  Gets the current version of a stream.

  ## Parameters
  - `stream_id`: Identifier of the stream
  - `opts`: Options for the operation

  ## Returns
  - `{:ok, version}` on success
  - `{:error, reason}` on failure
  """
  def stream_version(stream_id, opts \\ []) do
    with {:ok, adapter} <- get_adapter() do
      adapter.stream_version(stream_id, opts)
    end
  end

  @doc """
  Subscribes to a stream.

  ## Parameters
  - `stream_id`: Identifier of the stream to subscribe to
  - `subscriber`: PID of the subscriber process
  - `subscription_options`: Options for the subscription
  - `opts`: Options for the operation

  ## Returns
  - `{:ok, subscription}` on success
  - `{:error, reason}` on failure
  """
  def subscribe_to_stream(stream_id, subscriber, subscription_options \\ [], opts \\ []) do
    with {:ok, adapter} <- get_adapter() do
      adapter.subscribe_to_stream(stream_id, subscriber, subscription_options, opts)
    end
  end

  @doc """
  Unsubscribes from a stream.

  ## Parameters
  - `stream_id`: Identifier of the stream
  - `subscription`: Subscription identifier
  - `opts`: Options for the operation

  ## Returns
  - `:ok` on success
  - `{:error, reason}` on failure
  """
  def unsubscribe_from_stream(stream_id, subscription, opts \\ []) do
    with {:ok, adapter} <- get_adapter() do
      adapter.unsubscribe_from_stream(stream_id, subscription, opts)
    end
  end

  @doc """
  Deletes a stream.

  ## Parameters
  - `stream_id`: Identifier of the stream to delete
  - `expected_version`: Expected version of the stream for optimistic concurrency
  - `opts`: Options for the operation

  ## Returns
  - `:ok` on success
  - `{:error, reason}` on failure
  """
  def delete_stream(stream_id, expected_version \\ :any, opts \\ []) do
    with {:ok, adapter} <- get_adapter() do
      adapter.delete_stream(stream_id, expected_version, opts)
    end
  end

  # Private functions

  defp get_adapter do
    # Try to get configured adapter
    adapter = Application.get_env(:game_bot, :event_store_adapter, @fallback_adapter)

    # Ensure the adapter module is loaded and available
    case Code.ensure_loaded(adapter) do
      {:module, _} ->
        # Adapter module is available, return it
        {:ok, adapter}
      {:error, reason} ->
        {:error, Error.system_error(__MODULE__, "Event store adapter not available", reason)}
    end
  end
end

defmodule GameBot.Infrastructure.Persistence.EventStore.Adapter.Behaviour do
  @moduledoc """
  Defines the behaviour for event store adapters.

  This module provides the contract for interacting with an event store,
  including event appending, reading, and subscription management.

  Features:
  - Event stream operations
  - Optimistic concurrency control
  - Subscription management
  - Error handling
  - Telemetry integration
  """

  alias GameBot.Infrastructure.Error

  @type stream_id :: String.t()
  @type event :: struct()
  @type version :: non_neg_integer() | :any | :no_stream | :stream_exists
  @type subscriber :: pid()
  @type subscription :: reference()
  @type subscription_options :: keyword()
  @type operation_options :: keyword()

  @doc """
  Appends events to a stream with optimistic concurrency control.

  ## Parameters
    * `stream_id` - The unique identifier for the event stream
    * `expected_version` - The expected version of the stream
    * `events` - The list of events to append
    * `opts` - Optional operation parameters

  ## Returns
    * `{:ok, new_version}` - Events successfully appended
    * `{:error, Error.t()}` - Operation failed
  """
  @callback append_to_stream(stream_id(), version(), [event()], operation_options()) ::
    {:ok, non_neg_integer()} | {:error, Error.t()}

  @doc """
  Reads events from a stream in forward order.

  ## Parameters
    * `stream_id` - The unique identifier for the event stream
    * `start_version` - The version to start reading from
    * `count` - The maximum number of events to read
    * `opts` - Optional operation parameters

  ## Returns
    * `{:ok, events}` - Events successfully read
    * `{:error, Error.t()}` - Operation failed
  """
  @callback read_stream_forward(stream_id(), non_neg_integer(), pos_integer(), operation_options()) ::
    {:ok, [event()]} | {:error, Error.t()}

  @doc """
  Subscribes to a stream to receive new events.

  ## Parameters
    * `stream_id` - The unique identifier for the event stream
    * `subscriber` - The process to receive events
    * `subscription_options` - Options for the subscription
    * `opts` - Optional operation parameters

  ## Returns
    * `{:ok, subscription}` - Successfully subscribed
    * `{:error, Error.t()}` - Operation failed
  """
  @callback subscribe_to_stream(stream_id(), subscriber(), subscription_options(), operation_options()) ::
    {:ok, subscription()} | {:error, Error.t()}

  @doc """
  Gets the current version of a stream.

  ## Parameters
    * `stream_id` - The unique identifier for the event stream
    * `opts` - Optional operation parameters

  ## Returns
    * `{:ok, version}` - Current version retrieved
    * `{:error, Error.t()}` - Operation failed
  """
  @callback stream_version(stream_id(), operation_options()) ::
    {:ok, non_neg_integer()} | {:error, Error.t()}

  @doc """
  Deletes a stream.

  ## Parameters
    * `stream_id` - The unique identifier for the event stream
    * `expected_version` - The expected version of the stream
    * `opts` - Optional operation parameters

  ## Returns
    * `:ok` - Stream successfully deleted
    * `{:error, Error.t()}` - Operation failed
  """
  @callback delete_stream(stream_id(), version(), operation_options()) ::
    :ok | {:error, Error.t()}

  @doc """
  Links two streams together.

  ## Parameters
    * `source_stream_id` - The source stream identifier
    * `target_stream_id` - The target stream identifier
    * `opts` - Optional operation parameters

  ## Returns
    * `:ok` - Streams successfully linked
    * `{:error, Error.t()}` - Operation failed
  """
  @callback link_to_stream(stream_id(), stream_id(), operation_options()) ::
    :ok | {:error, Error.t()}

  @optional_callbacks [
    delete_stream: 3,
    link_to_stream: 3
  ]
end

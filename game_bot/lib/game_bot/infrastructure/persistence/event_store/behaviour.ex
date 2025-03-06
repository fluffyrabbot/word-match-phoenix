defmodule GameBot.Infrastructure.Persistence.EventStore.Behaviour do
  @moduledoc """
  Behavior definition for event store implementations.

  This module defines the contract for all event store implementations,
  ensuring consistent error handling, concurrency control, and operational
  semantics across different storage technologies.
  """

  alias GameBot.Infrastructure.Persistence.Error

  @doc """
  Appends events to a stream with optimistic concurrency control.

  ## Parameters
  - `stream_id` - The unique identifier for the stream
  - `expected_version` - The expected current version of the stream (for optimistic concurrency)
    - When `0`, expects the stream to be empty or non-existent
    - When a positive integer, expects the stream to be at exactly that version
  - `events` - A list of event maps/structs to append
  - `opts` - Options that may include:
    - `:timeout` - Maximum time in milliseconds to wait for the operation to complete
    - `:retries` - Number of times to retry on connection errors (default: 3)
    - `:metadata` - Additional metadata to store with the events

  ## Returns
  - `{:ok, events}` - Successfully appended events
  - `{:error, error}` - Error struct with type, context and details

  ## Error Types
  - `:concurrency` - When expected_version doesn't match actual version
  - `:validation` - When events are invalid
  - `:connection` - When persistence layer cannot be reached
  - `:timeout` - When operation takes longer than allowed time
  """
  @callback append_to_stream(
              stream_id :: String.t(),
              expected_version :: non_neg_integer(),
              events :: list(),
              opts :: keyword()
            ) :: {:ok, list()} | {:error, Error.t()}

  @doc """
  Reads events from a stream in forward direction (oldest to newest).

  ## Parameters
  - `stream_id` - The unique identifier for the stream
  - `start_version` - The version to start reading from (inclusive)
  - `count` - Maximum number of events to read
  - `opts` - Options that may include:
    - `:timeout` - Maximum time in milliseconds to wait for the operation to complete

  ## Returns
  - `{:ok, events}` - Successfully read events
  - `{:error, error}` - Error struct with type, context and details

  ## Error Types
  - `:not_found` - When stream doesn't exist
  - `:connection` - When persistence layer cannot be reached
  - `:timeout` - When operation takes longer than allowed time
  """
  @callback read_stream_forward(
              stream_id :: String.t(),
              start_version :: non_neg_integer(),
              count :: pos_integer(),
              opts :: keyword()
            ) :: {:ok, list()} | {:error, Error.t()}

  @doc """
  Subscribes to events from a specific stream.

  ## Parameters
  - `stream_id` - The unique identifier for the stream
  - `subscriber` - The pid of the process to receive events
  - `subscription_options` - Options for the subscription:
    - `:start_from` - `:origin` (all events) or specific version (default: `:origin`)
    - `:include_existing` - Whether to send existing events (default: `true`)
    - `:filter` - Optional function to filter events
  - `opts` - General options that may include:
    - `:timeout` - Maximum time in milliseconds to wait for subscription setup

  ## Returns
  - `{:ok, subscription_ref}` - Successfully subscribed, with reference for unsubscribing
  - `{:error, error}` - Error struct with type, context and details

  ## Event Delivery
  Events are delivered as `{:events, events}` messages to the subscriber pid.

  ## Error Types
  - `:not_found` - When stream doesn't exist
  - `:connection` - When persistence layer cannot be reached
  - `:timeout` - When operation takes longer than allowed time
  """
  @callback subscribe_to_stream(
              stream_id :: String.t(),
              subscriber :: pid(),
              subscription_options :: keyword(),
              opts :: keyword()
            ) :: {:ok, reference()} | {:error, Error.t()}

  @doc """
  Gets the current version of a stream.

  ## Parameters
  - `stream_id` - The unique identifier for the stream

  ## Returns
  - `{:ok, version}` - The current version of the stream (0 for non-existent streams)
  - `{:error, error}` - Error struct with type, context and details

  ## Error Types
  - `:connection` - When persistence layer cannot be reached
  """
  @callback stream_version(stream_id :: String.t()) :: {:ok, non_neg_integer()} | {:error, Error.t()}
end

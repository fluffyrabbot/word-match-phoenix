defmodule GameBot.Infrastructure.Persistence.EventStore.Postgres do
  @moduledoc """
  PostgreSQL-based event store implementation.
  Implements EventStore behaviour through macro.

  ## Macro Integration Guidelines

  This module uses the EventStore macro which generates several callback implementations.
  To maintain compatibility with the macro:

  1. DO NOT override these macro-generated functions:
     - `ack/2` - Event acknowledgment
     - `config/1` - Configuration handling
     - `subscribe/2` - Subscription management
     - Other standard EventStore callbacks

  2. ONLY override callbacks when adding functionality:
     - `init/1` - For additional initialization (e.g., telemetry)
     - Other callbacks where specific customization is needed

  3. DO add custom functions that:
     - Wrap macro-generated functions with additional safety/validation
     - Provide domain-specific functionality
     - Add monitoring or logging

  4. ALWAYS check the EventStore behaviour documentation before adding new functions
     to avoid naming conflicts with macro-generated functions.

  ## Implementation Notes

  This module is intentionally kept minimal to avoid conflicts with macro-generated functions.
  All custom functionality is implemented in the adapter layer.

  ## Example Usage

  ```elixir
  # DO - Add custom wrapper functions
  def safe_stream_version(stream_id) do
    # Custom validation and error handling
  end

  # DO - Override callbacks with @impl true when adding functionality
  @impl true
  def init(config) do
    # Add telemetry
    {:ok, config}
  end

  # DON'T - Override macro-generated functions
  # def config do  # This would conflict
  #   ...
  # end
  ```
  """

  use EventStore, otp_app: :game_bot
  require Logger

  # Type definitions for documentation and static analysis
  @type stream_id :: String.t()
  @type expected_version :: non_neg_integer() | :any | :no_stream | :stream_exists
  @type event :: term()
  @type append_error ::
    :wrong_expected_version |
    :stream_not_found |
    :invalid_stream_id |
    :invalid_expected_version |
    :serialization_failed |
    term()
  @type read_batch_size :: pos_integer()
  @type read_error ::
    :stream_not_found |
    :invalid_stream_id |
    :invalid_start_version |
    :invalid_batch_size |
    :deserialization_failed |
    term()

  # Configuration
  @telemetry_prefix [:game_bot, :event_store]

  @doc """
  Initialize the event store with configuration and setup monitoring.

  This is an override of the macro-generated init/1 to add telemetry support.
  We keep the original functionality (returning {:ok, config}) while adding our
  custom telemetry setup.
  """
  @impl true
  def init(config) do
    :telemetry.attach(
      "event-store-handler",
      @telemetry_prefix ++ [:event],
      &handle_telemetry_event/4,
      nil
    )

    {:ok, config}
  end

  # Private functions
  defp handle_telemetry_event(@telemetry_prefix ++ [:event], measurements, metadata, _config) do
    require Logger
    Logger.debug(fn ->
      "EventStore event: #{inspect(metadata)}\nMeasurements: #{inspect(measurements)}"
    end)
  end

  @doc """
  Get the current version of a stream with type safety and error handling.

  This is a custom wrapper around the macro-generated stream_info/1 function,
  adding additional validation and error handling.

  ## Parameters
    * `stream_id` - The stream identifier

  ## Returns
    * `{:ok, version}` - Success with current stream version where version is a non-negative integer
    * `{:error, :stream_not_found}` - Stream does not exist
    * `{:error, :invalid_stream_id}` - Stream ID is invalid
    * `{:error, term()}` - Other error with reason
  """
  @spec safe_stream_version(stream_id()) :: {:ok, non_neg_integer()} | {:error, :stream_not_found | :invalid_stream_id | term()}
  def safe_stream_version(stream_id) when is_binary(stream_id) do
    case stream_info(stream_id) do
      {:ok, %{stream_version: version}} when is_integer(version) and version >= 0 ->
        {:ok, version}
      {:error, :stream_not_found} = err ->
        err
      {:error, reason} ->
        Logger.warning("Error getting stream version: #{inspect(reason)}")
        {:error, reason}
    end
  end
  def safe_stream_version(_), do: {:error, :invalid_stream_id}

  @doc """
  Type-safe wrapper for appending events to a stream.

  This is a custom wrapper around the macro-generated append_to_stream/4 function,
  adding validation, error handling, and logging.
  """
  @spec safe_append_to_stream(stream_id(), expected_version(), [event()], keyword()) ::
    {:ok, non_neg_integer()} | {:error, append_error()}
  def safe_append_to_stream(stream_id, expected_version, events, opts \\ [])
  def safe_append_to_stream(stream_id, expected_version, events, opts) when is_binary(stream_id) do
    with :ok <- validate_expected_version(expected_version),
         :ok <- validate_events(events) do
      try do
        case append_to_stream(stream_id, expected_version, events, opts) do
          {:ok, version} when is_integer(version) and version >= 0 ->
            {:ok, version}
          {:error, :wrong_expected_version} = err ->
            err
          {:error, :stream_not_found} = err ->
            err
          {:error, reason} ->
            Logger.warning("Error appending to stream: #{inspect(reason)}")
            {:error, reason}
        end
      rescue
        e in ArgumentError ->
          Logger.error("Invalid argument in append_to_stream: #{inspect(e)}")
          {:error, :invalid_stream_id}
        e ->
          Logger.error("Error in append_to_stream: #{inspect(e)}")
          {:error, :serialization_failed}
      end
    end
  end
  def safe_append_to_stream(_, _, _, _), do: {:error, :invalid_stream_id}

  @doc """
  Type-safe wrapper for reading events from a stream.

  This is a custom wrapper around the macro-generated read_stream_forward/4 function,
  adding validation, error handling, and logging.
  """
  @spec safe_read_stream_forward(stream_id(), non_neg_integer(), read_batch_size()) ::
    {:ok, [event()]} | {:error, read_error()}
  def safe_read_stream_forward(stream_id, start_version \\ 0, batch_size \\ 1000)
  def safe_read_stream_forward(stream_id, start_version, batch_size)
      when is_binary(stream_id) and
           is_integer(start_version) and start_version >= 0 and
           is_integer(batch_size) and batch_size > 0 do
    try do
      case read_stream_forward(stream_id, start_version, batch_size) do
        {:ok, events} when is_list(events) ->
          {:ok, events}
        {:error, :stream_not_found} = err ->
          err
        {:error, reason} ->
          Logger.warning("Error reading stream forward: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      e in ArgumentError ->
        Logger.error("Invalid argument in read_stream_forward: #{inspect(e)}")
        {:error, :invalid_stream_id}
      e ->
        Logger.error("Error in read_stream_forward: #{inspect(e)}")
        {:error, :deserialization_failed}
    end
  end
  def safe_read_stream_forward(stream_id, _, _) when not is_binary(stream_id),
    do: {:error, :invalid_stream_id}
  def safe_read_stream_forward(_, start_version, _) when not is_integer(start_version) or start_version < 0,
    do: {:error, :invalid_start_version}
  def safe_read_stream_forward(_, _, batch_size) when not is_integer(batch_size) or batch_size <= 0,
    do: {:error, :invalid_batch_size}

  # Validation helpers
  defp validate_expected_version(version) when is_integer(version) and version >= 0, do: :ok
  defp validate_expected_version(version) when version in [:any, :no_stream, :stream_exists], do: :ok
  defp validate_expected_version(_), do: {:error, :invalid_expected_version}

  defp validate_events([]), do: {:error, :empty_event_list}
  defp validate_events(events) when is_list(events), do: :ok
  defp validate_events(_), do: {:error, :invalid_events}
end

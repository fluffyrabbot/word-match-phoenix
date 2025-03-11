defmodule GameBot.Infrastructure.Persistence.EventStore.Adapter.Base do
  @moduledoc """
  Base implementation for event store adapters.

  This module provides common functionality that can be used by concrete
  adapter implementations, including:
  - Error handling
  - Retry mechanisms
  - Telemetry integration
  - Validation
  """

  alias GameBot.Infrastructure.Error
  alias GameBot.Infrastructure.ErrorHelpers
  alias GameBot.Infrastructure.Persistence.EventStore.Adapter.Behaviour
  alias GameBot.Infrastructure.Persistence.EventStore.Serialization.JsonSerializer

  @type operation :: :append | :read | :subscribe | :version | :delete | :link
  @type telemetry_data :: %{
    operation: operation(),
    stream_id: Behaviour.stream_id(),
    start_time: integer(),
    end_time: integer(),
    result: :ok | :error,
    error: Error.t() | nil,
    metadata: map()
  }

  defmacro __using__(opts) do
    quote location: :keep do
      @behaviour Behaviour

      alias GameBot.Infrastructure.Error
      alias GameBot.Infrastructure.ErrorHelpers
      alias GameBot.Infrastructure.Persistence.EventStore.Adapter.{Base, Behaviour}

      @serializer Keyword.get(unquote(opts), :serializer, JsonSerializer)
      @max_retries Keyword.get(unquote(opts), :max_retries, 3)
      @initial_delay Keyword.get(unquote(opts), :initial_delay, 50)

      @impl Behaviour
      def append_to_stream(stream_id, expected_version, events, opts \\ []) do
        Base.with_telemetry(__MODULE__, :append, stream_id, fn ->
          Base.with_retries(
            fn ->
              with {:ok, prepared_events} <- prepare_events(stream_id, events),
                   {:ok, serialized} <- serialize_events(prepared_events),
                   {:ok, result} <- do_append_to_stream(stream_id, expected_version, serialized, opts) do
                {:ok, result}
              end
            end,
            __MODULE__,
            max_retries: @max_retries,
            initial_delay: @initial_delay
          )
        end)
      end

      @impl Behaviour
      def read_stream_forward(stream_id, start_version \\ 0, count \\ 1000, opts \\ []) do
        Base.with_telemetry(__MODULE__, :read, stream_id, fn ->
          Base.with_retries(
            fn ->
              with {:ok, events} <- do_read_stream_forward(stream_id, start_version, count, opts),
                   {:ok, deserialized} <- deserialize_events(events) do
                {:ok, deserialized}
              end
            end,
            __MODULE__,
            max_retries: @max_retries,
            initial_delay: @initial_delay
          )
        end)
      end

      @impl Behaviour
      def subscribe_to_stream(stream_id, subscriber, subscription_options \\ [], opts \\ []) do
        Base.with_telemetry(__MODULE__, :subscribe, stream_id, fn ->
          Base.with_retries(
            fn ->
              do_subscribe_to_stream(stream_id, subscriber, subscription_options, opts)
            end,
            __MODULE__,
            max_retries: @max_retries,
            initial_delay: @initial_delay
          )
        end)
      end

      @impl Behaviour
      def stream_version(stream_id, opts \\ []) do
        Base.with_telemetry(__MODULE__, :version, stream_id, fn ->
          Base.with_retries(
            fn ->
              do_stream_version(stream_id, opts)
            end,
            __MODULE__,
            max_retries: @max_retries,
            initial_delay: @initial_delay
          )
        end)
      end

      # Optional callbacks with default implementations

      @impl Behaviour
      def delete_stream(stream_id, expected_version, opts \\ []) do
        Base.with_telemetry(__MODULE__, :delete, stream_id, fn ->
          Base.with_retries(
            fn ->
              do_delete_stream(stream_id, expected_version, opts)
            end,
            __MODULE__,
            max_retries: @max_retries,
            initial_delay: @initial_delay
          )
        end)
        |> case do
          {:ok, :ok} -> :ok  # Convert {:ok, :ok} to :ok for the Behaviour
          other -> other     # Pass through other return values
        end
      end

      @impl Behaviour
      def link_to_stream(source_stream_id, target_stream_id, opts \\ []) do
        Base.with_telemetry(__MODULE__, :link, source_stream_id, fn ->
          Base.with_retries(
            fn ->
              do_link_to_stream(source_stream_id, target_stream_id, opts)
            end,
            __MODULE__,
            max_retries: @max_retries,
            initial_delay: @initial_delay
          )
        end)
      end

      # Overridable callbacks for concrete implementations

      defp do_append_to_stream(stream_id, expected_version, events, opts) do
        with {:ok, prepared_events} <- prepare_events(stream_id, events) do
          {:ok, serialize_events(prepared_events)}
        end
      end

      defp do_read_stream_forward(_stream_id, _start_version, _count, _opts) do
        {:error, Error.not_found_error(__MODULE__, "Operation not implemented")}
      end

      defp do_subscribe_to_stream(_stream_id, _subscriber, _subscription_options, _opts) do
        {:error, Error.not_found_error(__MODULE__, "Operation not implemented")}
      end

      defp do_stream_version(_stream_id, _opts) do
        {:error, Error.not_found_error(__MODULE__, "Operation not implemented")}
      end

      defp do_delete_stream(_stream_id, _expected_version, _opts) do
        {:error, Error.not_found_error(__MODULE__, "Operation not implemented")}
      end

      defp do_link_to_stream(_source_stream_id, _target_stream_id, _opts) do
        {:error, Error.not_found_error(__MODULE__, "Operation not implemented")}
      end

      # Private helper functions

      defp serialize_events(events) when is_list(events) do
        events
        |> Enum.reduce_while({:ok, []}, fn event, {:ok, acc} ->
          case @serializer.serialize(event) do
            {:ok, serialized} -> {:cont, {:ok, [serialized | acc]}}
            error -> {:halt, error}
          end
        end)
        |> case do
          {:ok, serialized} -> {:ok, Enum.reverse(serialized)}
          error -> error
        end
      end

      defp deserialize_events(events) when is_list(events) do
        events
        |> Enum.reduce_while({:ok, []}, fn event, {:ok, acc} ->
          case @serializer.deserialize(event) do
            {:ok, deserialized} -> {:cont, {:ok, [deserialized | acc]}}
            error -> {:halt, error}
          end
        end)
        |> case do
          {:ok, deserialized} -> {:ok, Enum.reverse(deserialized)}
          error -> error
        end
      end

      defp prepare_events(stream_id, events) when is_list(events) do
        prepared = Enum.map(events, fn event ->
          case event do
            %{stream_id: _} -> event
            _ when is_map(event) -> Map.put(event, :stream_id, stream_id)
            _ -> event
          end
        end)
        {:ok, prepared}
      end

      defp prepare_events(_stream_id, events) do
        {:error, Error.validation_error(__MODULE__, "Events must be a list", events)}
      end

      defoverridable [
        do_append_to_stream: 4,
        do_read_stream_forward: 4,
        do_subscribe_to_stream: 4,
        do_stream_version: 2,
        do_delete_stream: 3,
        do_link_to_stream: 3
      ]
    end
  end

  @doc """
  Executes an operation with telemetry events.
  """
  def with_telemetry(adapter, operation, stream_id, fun) do
    start_time = System.monotonic_time()

    result =
      try do
        fun.()
      rescue
        e ->
          {:error, Error.system_error(adapter, Exception.message(e), e)}
      end

    end_time = System.monotonic_time()
    metadata = %{adapter: adapter}

    telemetry_data = %{
      operation: operation,
      stream_id: stream_id,
      start_time: start_time,
      end_time: end_time,
      result: elem(result, 0),
      error: if(elem(result, 0) == :error, do: elem(result, 1)),
      metadata: metadata
    }

    :telemetry.execute(
      [:game_bot, :event_store, operation],
      %{duration: end_time - start_time},
      telemetry_data
    )

    result
  end

  @doc """
  Executes an operation with retries on transient errors.
  """
  def with_retries(fun, context, opts \\ []) do
    ErrorHelpers.with_retries(fun, context, opts)
  end
end

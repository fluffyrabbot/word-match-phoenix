defmodule GameBot.Domain.Events.Handler do
  @moduledoc """
  Basic behaviour for creating event handlers with error handling.
  """

  @callback handle_event(event :: struct()) :: :ok | {:error, term()}
  @callback interests() :: [String.t()]

  defmacro __using__(opts) do
    quote do
      use GenServer
      require Logger

      @behaviour GameBot.Domain.Events.Handler

      # Default implementation of interests
      @impl true
      def interests do
        unquote(opts[:interests] || [])
      end

      def start_link(args \\ []) do
        GenServer.start_link(__MODULE__, args, name: __MODULE__)
      end

      @impl true
      def init(args) do
        # Subscribe to all interests
        subscribe_to_interests()
        {:ok, Map.new(args)}
      end

      @impl true
      def handle_info({:event, event}, state) do
        try do
          case handle_event(event) do
            :ok -> {:noreply, state}
            {:error, reason} ->
              Logger.error("Error handling event #{inspect(event.__struct__)}: #{inspect(reason)}")
              {:noreply, state}
          end
        rescue
          e ->
            Logger.error("Exception while handling event: #{Exception.message(e)}")
            # Resubscribe to topics
            subscribe_to_interests()
            {:noreply, state}
        end
      end

      defp subscribe_to_interests do
        alias GameBot.Domain.Events.SubscriptionManager

        # Subscribe to each interest
        for interest <- interests() do
          case interest do
            "game:" <> game_id -> SubscriptionManager.subscribe_to_game(game_id)
            "event_type:" <> type -> SubscriptionManager.subscribe_to_event_type(type)
            _ -> Phoenix.PubSub.subscribe(GameBot.PubSub, interest)
          end
        end
      end

      # Allow overriding of handle_info
      defoverridable handle_info: 2
    end
  end
end

defmodule GameBot.Domain.Events.SubscriptionManager do
  @moduledoc """
  Manages subscriptions to event topics with standardized patterns.
  """

  alias Phoenix.PubSub

  @pubsub GameBot.PubSub

  # Game-specific subscriptions
  @doc """
  Subscribes the current process to all events for a specific game.
  """
  @spec subscribe_to_game(String.t()) :: :ok | {:error, term()}
  def subscribe_to_game(game_id) do
    PubSub.subscribe(@pubsub, "game:#{game_id}")
  end

  # Event type subscriptions
  @doc """
  Subscribes the current process to all events of a specific type, across all games.
  """
  @spec subscribe_to_event_type(String.t()) :: :ok | {:error, term()}
  def subscribe_to_event_type(type) do
    PubSub.subscribe(@pubsub, "event_type:#{type}")
  end

  # Unsubscribe from any topic
  @doc """
  Unsubscribes the current process from a topic.
  """
  @spec unsubscribe(String.t()) :: :ok | {:error, term()}
  def unsubscribe(topic) do
    PubSub.unsubscribe(@pubsub, topic)
  end
end

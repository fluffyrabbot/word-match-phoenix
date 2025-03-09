defmodule GameBot.Domain.Events.Examples.GameCompletionNotifier do
  @moduledoc """
  Example event handler that demonstrates using the Handler behavior.

  This handler subscribes to all game_completed events and logs information about them.
  In a real implementation, this might send notifications to a webhook, save statistics, etc.

  To use this in your application:

  1. Add it to your supervision tree
  2. Enable the enhanced PubSub system
  """

  use GameBot.Domain.Events.Handler,
    interests: ["event_type:game_completed"]

  require Logger

  @impl true
  def handle_event(%{__struct__: module} = event) do
    if event_type_matches?(module) do
      process_game_completion(event)
    else
      # Not a game completed event, which shouldn't happen with our interests
      # but handling defensively
      :ok
    end
  end

  # Handle any other unexpected message type
  def handle_event(_), do: :ok

  # Private helper functions

  defp event_type_matches?(module) do
    module_name = Atom.to_string(module)
    String.contains?(module_name, "GameCompleted")
  end

  defp process_game_completion(event) do
    Logger.info("""
    Game completed: #{event.game_id}
    Mode: #{event.mode}
    Players: #{inspect(extract_players(event))}
    Duration: #{format_duration(event)}
    """)

    # In a real implementation, we might:
    # - Record statistics
    # - Send webhook notifications
    # - Update leaderboards
    # - Trigger rewards

    :ok
  end

  defp extract_players(event) do
    event.metadata["players"] || []
  end

  defp format_duration(event) do
    start_time = event.metadata["game_start_time"]
    end_time = event.timestamp

    if start_time do
      case DateTime.from_iso8601(start_time) do
        {:ok, start_datetime, _} ->
          duration_seconds = DateTime.diff(end_time, start_datetime)
          "#{div(duration_seconds, 60)}m #{rem(duration_seconds, 60)}s"
        _ ->
          "Unknown"
      end
    else
      "Unknown"
    end
  end
end

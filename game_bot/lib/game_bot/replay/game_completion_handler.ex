defmodule GameBot.Replay.GameCompletionHandler do
  @moduledoc """
  Handles game completion events and creates replay records.

  This module subscribes to GameCompleted events, processes the event stream,
  calculates statistics, and creates a lightweight replay reference with a
  memorable name that points to the original event stream.
  """

  use GameBot.Domain.Events.Handler,
    interests: ["event_type:game_completed"]

  require Logger

  alias GameBot.Replay.{
    EventStoreAccess,
    EventVerifier,
    VersionCompatibility,
    Types,
    Storage,
    Utils.NameGenerator,
    Utils.StatsCalculator
  }
  alias GameBot.Domain.Events.SubscriptionManager

  @impl true
  def handle_event(event) do
    case process_game_completed(event) do
      {:ok, replay_id} ->
        Logger.info("Created replay for game #{event.game_id}, replay_id: #{replay_id}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to create replay for game #{event.game_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Processes a game completion event and creates a replay reference.

  ## Parameters
    - event: The GameCompleted event

  ## Returns
    - {:ok, replay_id} - Successfully created replay
    - {:error, reason} - Failed to create replay
  """
  @spec process_game_completed(map()) :: {:ok, Types.replay_id()} | {:error, term()}
  def process_game_completed(event) do
    game_id = event.game_id
    opts = %{
      check_completion: true,
      required_events: ["game_started", "game_completed"],
      max_events: 2000
    }

    with {:ok, events} <- fetch_and_verify_events(game_id, opts),
         {:ok, version_map} <- VersionCompatibility.validate_replay_compatibility(events),
         {:ok, base_stats} <- StatsCalculator.calculate_base_stats(events),
         {:ok, mode_stats} <- StatsCalculator.calculate_mode_stats(events, event.mode),
         {:ok, display_name} <- generate_unique_name(),
         replay <- build_replay_reference(game_id, event, events, base_stats, mode_stats, version_map, display_name),
         {:ok, stored_replay} <- Storage.store_replay(replay) do

      Logger.info("Created replay '#{display_name}' for game #{game_id}")
      {:ok, stored_replay.replay_id}
    else
      {:error, reason} ->
        Logger.error("Failed to create replay for game #{game_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Fetches and verifies the event stream for a game.
  #
  # Parameters:
  #   - game_id: The ID of the game
  #   - opts: Options for event retrieval and verification
  #
  # Returns:
  #   - {:ok, events} - Successfully fetched and verified events
  #   - {:error, reason} - Failed to fetch or verify events
  @spec fetch_and_verify_events(Types.game_id(), map()) ::
    {:ok, list(map())} | {:error, term()}
  defp fetch_and_verify_events(game_id, opts) do
    with {:ok, events} <- EventStoreAccess.fetch_game_events(game_id, [
           max_events: Map.get(opts, :max_events, 1000)
         ]),
         :ok <- EventVerifier.verify_game_stream(events, [
           required_events: Map.get(opts, :required_events, ["game_started"]),
           check_completion: Map.get(opts, :check_completion, true)
         ]) do
      {:ok, events}
    end
  end

  # Generates a unique display name for the replay.
  #
  # Returns:
  #   - {:ok, name} - Successfully generated name
  #   - {:error, reason} - Failed to generate name
  @spec generate_unique_name() :: {:ok, Types.display_name()} | {:error, term()}
  defp generate_unique_name do
    case Storage.list_replays() do
      {:ok, existing_replays} ->
        existing_names = Enum.map(existing_replays, & &1.display_name)
        NameGenerator.generate_name(existing_names)

      {:error, _} = error ->
        # If we can't get existing names, try without collision detection
        Logger.warning("Could not fetch existing replay names: #{inspect(error)}")
        NameGenerator.generate_name()
    end
  end

  # Builds a replay reference from the completed game data.
  #
  # Parameters:
  #   - game_id: The ID of the game
  #   - event: The GameCompleted event
  #   - events: The full event stream
  #   - base_stats: The calculated base statistics
  #   - mode_stats: The calculated mode-specific statistics
  #   - version_map: Map of event types to their versions
  #   - display_name: The generated display name
  #
  # Returns a replay reference map
  @spec build_replay_reference(
    Types.game_id(),
    map(),
    list(map()),
    Types.base_stats(),
    map(),
    map(),
    Types.display_name()
  ) :: Types.replay_reference()
  defp build_replay_reference(game_id, event, events, base_stats, mode_stats, version_map, display_name) do
    # Find start time from the first event
    start_event = Enum.find(events, fn e -> e.event_type == "game_started" end)

    # Use completion event timestamp as end time
    end_time = event.timestamp

    # Create the replay reference
    %{
      replay_id: nil, # Will be generated on insert
      game_id: game_id,
      display_name: display_name,
      mode: event.mode,
      start_time: start_event.timestamp,
      end_time: end_time,
      event_count: length(events),
      base_stats: base_stats,
      mode_stats: mode_stats,
      version_map: version_map,
      created_at: DateTime.utc_now()
    }
  end

  @doc """
  Manually subscribes to game completion events.
  This can be called to re-establish subscriptions if needed.

  ## Returns
    - :ok - Successfully subscribed
    - {:error, reason} - Failed to subscribe
  """
  @spec subscribe() :: :ok | {:error, term()}
  def subscribe do
    SubscriptionManager.subscribe_to_event_type("game_completed")
  end
end

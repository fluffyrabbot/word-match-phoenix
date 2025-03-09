defmodule GameBot.Replay.GameCompletionHandler do
  @moduledoc """
  Handles game completion events and creates replay records.

  This module subscribes to GameCompleted events, processes the event stream,
  calculates statistics, and creates a lightweight replay reference with a
  memorable name that points to the original event stream.
  """

  require Logger
  alias GameBot.Replay.Utils.NameGenerator
  alias GameBot.Replay.Utils.StatsCalculator
  alias GameBot.Repo

  @doc """
  Processes a game completion event and creates a replay reference.

  ## Parameters
  - `event` - The GameCompleted event

  ## Returns
  - `{:ok, replay_id}` - If replay was successfully created
  - `{:error, reason}` - If replay creation failed
  """
  @spec process_game_completed(map()) :: {:ok, String.t()} | {:error, term()}
  def process_game_completed(event) do
    game_id = event.game_id

    # Get the full event stream for the game
    with {:ok, events} <- get_event_stream(game_id),
         {:ok, base_stats} <- StatsCalculator.calculate_base_stats(events),
         {:ok, mode_stats} <- calculate_mode_specific_stats(events, event.mode),
         {:ok, replay_name} <- NameGenerator.generate(),
         {:ok, replay_id} <- store_replay(game_id, event, base_stats, mode_stats, replay_name) do

      Logger.info("Created replay '#{replay_name}' (ID: #{replay_id}) for game #{game_id}")
      {:ok, replay_id}
    else
      {:error, reason} ->
        Logger.error("Failed to create replay for game #{game_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Retrieves the complete event stream for a game from the EventStore.
  """
  @spec get_event_stream(String.t()) :: {:ok, [map()]} | {:error, term()}
  defp get_event_stream(game_id) do
    # This would be replaced with actual EventStore.read_stream_forward call
    # For now, just stubbing the function
    {:ok, []}
  end

  @doc """
  Calculates mode-specific statistics based on the event stream and game mode.
  """
  @spec calculate_mode_specific_stats([map()], atom()) :: {:ok, map()} | {:error, term()}
  defp calculate_mode_specific_stats(events, mode) do
    # Get the appropriate replay module for this mode
    replay_module = get_replay_module(mode)

    # Build a temporary replay to calculate stats
    with {:ok, replay} <- replay_module.build_replay(events) do
      stats = replay_module.calculate_mode_stats(replay)
      {:ok, stats}
    else
      error -> error
    end
  end

  @doc """
  Gets the replay implementation module for a given game mode.
  """
  @spec get_replay_module(atom()) :: module()
  defp get_replay_module(mode) do
    case mode do
      :two_player -> GameBot.Replay.TwoPlayerReplay
      :knockout -> GameBot.Replay.KnockoutReplay
      :race -> GameBot.Replay.RaceReplay
      :golf_race -> GameBot.Replay.GolfRaceReplay
      _ -> GameBot.Replay.DefaultReplay
    end
  end

  @doc """
  Stores a replay reference in the database.

  Creates a new record in the game_replays table with:
  - A unique replay_id (UUID)
  - Reference to the original game_id
  - Memorable display_name
  - Pre-calculated statistics
  - Game metadata

  ## Returns
  - `{:ok, replay_id}` - The UUID of the created replay
  - `{:error, reason}` - If storage failed
  """
  @spec store_replay(String.t(), map(), map(), map(), String.t()) :: {:ok, String.t()} | {:error, term()}
  defp store_replay(game_id, event, base_stats, mode_stats, display_name) do
    # Generate a UUID for the replay
    replay_id = UUID.uuid4()

    # Insert the replay reference into the database
    params = %{
      replay_id: replay_id,
      game_id: game_id,
      mode: Atom.to_string(event.mode),
      start_time: event.start_time,
      end_time: event.timestamp,
      base_stats: Jason.encode!(base_stats),
      mode_stats: Jason.encode!(mode_stats),
      display_name: display_name,
      created_at: DateTime.utc_now()
    }

    case Repo.insert_all("game_replays", [params], returning: [:replay_id]) do
      {1, [%{replay_id: inserted_id}]} -> {:ok, inserted_id}
      {0, _} -> {:error, :insert_failed}
      error -> {:error, error}
    end
  end

  @doc """
  Subscribes this handler to GameCompleted events.

  Called when the application starts to set up the event subscription.
  """
  @spec subscribe() :: :ok | {:error, term()}
  def subscribe do
    # This would be replaced with actual event subscription
    # For example, using Phoenix PubSub or a custom event system
    :ok
  end
end

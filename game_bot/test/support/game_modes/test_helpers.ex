defmodule GameBot.Test.GameModes.TestHelpers do
  @moduledoc """
  Test helpers for game modes. Provides utilities for building test states,
  simulating game sequences, and verifying event sequences.
  """

  alias GameBot.Domain.GameState

  # Use more specific aliases for events
  alias GameBot.Domain.Events.GameEvents.{
    GameCreated,
    PlayerJoined,
    GameStarted,
    GuessProcessed,
    GuessAbandoned,
    TeamEliminated,
    GameCompleted
  }

  @doc """
  Builds a test game state with the given parameters based on the actual GameState struct.

  ## Parameters
  - `guild_id` - The Discord guild ID for the game
  - `attrs` - A map of attributes to override the defaults
  """
  def build_test_state(guild_id, attrs \\ %{}) do
    # Use the actual fields from the GameState struct
    default_state = %{
      guild_id: guild_id,
      mode: Map.get(attrs, :mode, :standard),
      teams: Map.get(attrs, :teams, %{}),
      team_ids: Map.get(attrs, :team_ids, []),
      forbidden_words: Map.get(attrs, :forbidden_words, %{}),
      round_number: Map.get(attrs, :round_number, 1),
      start_time: Map.get(attrs, :start_time, DateTime.utc_now()),
      last_activity: Map.get(attrs, :last_activity, DateTime.utc_now()),
      matches: Map.get(attrs, :matches, []),
      scores: Map.get(attrs, :scores, %{}),
      status: Map.get(attrs, :status, :waiting)
    }

    struct(GameState, Map.merge(default_state, attrs))
  end

  @doc """
  Creates a test game with the given parameters.
  """
  def create_test_game(guild_id, attrs \\ %{}) do
    event = %GameCreated{
      guild_id: guild_id,
      mode: Map.get(attrs, :mode, :standard),
      created_at: DateTime.utc_now(),
      created_by: Map.get(attrs, :created_by, "test-user")
    }

    {:ok, event}
  end

  @doc """
  Adds a player to a test game.
  """
  def add_test_player(game_id, guild_id, player_id, attrs \\ %{}) do
    event = %GameBot.Domain.Events.GameEvents.PlayerJoined{
      game_id: game_id,
      guild_id: guild_id,
      player_id: player_id,
      username: Map.get(attrs, :username, "TestUser"),
      joined_at: DateTime.utc_now(),
      metadata: %{}
    }

    {:ok, event}
  end

  @doc """
  Simulates a sequence of game events, applying them to the state.
  """
  def simulate_game_sequence(state, events) do
    Enum.reduce(events, state, fn event, acc_state ->
      case apply_event(acc_state, event) do
        {:ok, new_state, _events} -> new_state
        {:ok, new_state} -> new_state
        {:error, reason} -> raise "Failed to apply event: #{inspect(reason)}"
      end
    end)
  end

  @doc """
  Verifies that a sequence of events matches expected types.
  """
  def verify_event_sequence(events, expected_types) do
    actual_types = Enum.map(events, &event_type/1)

    if actual_types == expected_types do
      :ok
    else
      {:error, %{expected: expected_types, actual: actual_types}}
    end
  end

  # Private helpers

  defp event_type(event), do: event.__struct__.event_type()

  defp apply_event(state, %GameStarted{} = event) do
    state = %{state |
      mode: event.mode,
      teams: event.teams,
      round_number: 1,
      status: :initialized
    }
    {:ok, state, [event]}
  end

  defp apply_event(state, %GuessProcessed{} = event) do
    state = if event.guess_successful do
      update_in(state.scores[event.team_id], &(&1 + event.match_score))
    else
      update_in(state.teams[event.team_id].guess_count, &(&1 + 1))
    end
    {:ok, state, [event]}
  end

  defp apply_event(state, %GuessAbandoned{} = event) do
    state = update_in(state.teams[event.team_id].guess_count, &(&1 + 1))
    {:ok, state, [event]}
  end

  defp apply_event(state, %TeamEliminated{} = event) do
    state = update_in(state.teams, &Map.delete(&1, event.team_id))
    {:ok, state, [event]}
  end

  defp apply_event(state, %GameCompleted{} = event) do
    state = %{state | status: :completed, scores: event.final_scores}
    {:ok, state, [event]}
  end
end

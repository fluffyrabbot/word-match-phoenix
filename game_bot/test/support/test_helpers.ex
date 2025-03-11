defmodule GameBot.TestHelpers do
  @moduledoc """
  Common helper functions for test setup and teardown.

  These functions help with:
  - Setting up the test environment
  - Cleaning up after tests
  - Bypassing certain validations for testing
  - Creating test game states and events
  """

  require Logger

  @doc """
  Apply test environment settings. This should be called in setup_all
  to prepare the testing environment.
  """
  def apply_test_environment do
    # Start required services or set test flags
    Logger.debug("Applying test environment settings")

    # Ensure mock services are set up if needed
    Application.put_env(:game_bot, :test_mode, true)

    # Disable word validation for tests
    Application.put_env(:game_bot, :word_validation_enabled, false)

    # Set environment variable for tests
    System.put_env("GAMEBOT_DISABLE_WORD_VALIDATION", "true")

    :ok
  end

  @doc """
  Clean up the test environment. This should be called after tests
  complete to ensure a clean state for future test runs.
  """
  def cleanup_test_environment do
    Logger.debug("Cleaning up test environment")

    # Reset any test flags or configurations
    Application.delete_env(:game_bot, :test_mode)
    Application.delete_env(:game_bot, :mock_word_service)
    Application.delete_env(:game_bot, :word_validation_enabled)

    # Clear environment variable
    System.delete_env("GAMEBOT_DISABLE_WORD_VALIDATION")

    :ok
  end

  @doc """
  Bypass word validations in game mode states.

  This allows tests to use any words without failing validation by:
  1. Clearing all forbidden words at the top level and in teams
  2. Adding validation_disabled flags to the state
  3. Setting appropriate environment variables

  ## Parameters
    * state - The game state to modify

  ## Returns
    * Modified state with word validations bypassed
  """
  def bypass_word_validations(state) do
    # Set environment variables to bypass validation at runtime
    System.put_env("GAMEBOT_DISABLE_WORD_VALIDATION", "true")
    Application.put_env(:game_bot, :word_validation_enabled, false)

    # Check if this is a GameState struct or a regular map
    state = cond do
      is_struct(state) ->
        # Handle GameState struct
        %{state | forbidden_words: %{}}
      is_map(state) ->
        # This is likely a plain map used in game mode tests
        state
        |> Map.put(:forbidden_words, %{})
        |> Map.put(:validation_disabled, true)
      true ->
        state
    end

    # Add validation bypass flags
    state = put_in_if_exists(state, [:validation_disabled], true)
    state = put_in_if_exists(state, [:word_validation_disabled], true)

    # Clear team-specific forbidden words if they exist
    state = if Map.has_key?(state, :teams) do
      teams = state.teams
      |> Enum.map(fn {team_id, team} ->
        updated_team = case team do
          %{forbidden_words: _} when is_map(team) ->
            # If the team has a forbidden_words field, update it
            # Note: It could be a MapSet or a map
            Map.put(team, :forbidden_words, MapSet.new())
          _ ->
            # Otherwise, just return the team as is
            team
        end
        {team_id, updated_team}
      end)
      |> Map.new()

      Map.put(state, :teams, teams)
    else
      state
    end

    # Initialize forbidden_words for each player if not already present
    player_ids = state
    |> Map.get(:teams, %{})
    |> Enum.flat_map(fn {_team_id, team} ->
      Map.get(team, :players, [])
    end)

    forbidden_words = Enum.reduce(player_ids, %{}, fn player_id, acc ->
      Map.put(acc, player_id, [])
    end)

    Map.put(state, :forbidden_words, forbidden_words)
  end

  @doc """
  Helper function to safely put a value in a nested map only if the path exists.

  ## Parameters
    * map - The map to update
    * path - The key path as a list
    * value - The value to set

  ## Returns
    * Updated map if path exists, original map otherwise
  """
  def put_in_if_exists(map, path, value) do
    try do
      put_in(map, path, value)
    rescue
      _ -> map
    end
  end

  @doc """
  Create a test event with valid base fields.

  ## Parameters
    * type - The event type string
    * data - The event data

  ## Returns
    * A map representing a valid event with all required fields
  """
  def create_test_event(type, data) do
    %{
      event_type: type,
      data: data,
      metadata: %{
        "correlation_id" => "test-#{:erlang.unique_integer()}",
        "source_id" => "test",
        "guild_id" => data[:guild_id] || "test-guild"
      },
      timestamp: DateTime.utc_now()
    }
  end

  @doc """
  Create a test game state for a specific game mode.

  ## Parameters
    * mode - The game mode module
    * game_id - The game ID
    * teams - Map of team IDs to player lists
    * config - Configuration for the game mode

  ## Returns
    * {:ok, state} - The initialized game state
    * {:error, reason} - Error with initialization
  """
  def create_test_game_state(mode, game_id, teams, config) do
    with {:ok, state, _events} <- mode.init(game_id, teams, config) do
      state = bypass_word_validations(state)
      {:ok, state}
    end
  end
end

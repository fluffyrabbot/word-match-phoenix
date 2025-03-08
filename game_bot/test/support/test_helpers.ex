defmodule GameBot.TestHelpers do
  @moduledoc """
  Helper functions for testing GameBot.

  This module provides utilities and bypasses needed for testing certain
  game functionality without having to set up complete environments.
  """

  @doc """
  Creates a mocked version of a GameState with word_forbidden? always returning false.

  This is useful for tests that should not fail on word_forbidden checks,
  which often happens in validation tests where we want to test other aspects
  of game mechanics.

  ## Parameters
    * `state` - The GameState to modify

  ## Returns
    * A modified GameState with empty forbidden_words and word_forbidden? that always returns {:ok, false}
  """
  def bypass_word_validations(state) do
    # Create empty forbidden_words for all players
    player_ids = Enum.flat_map(state.teams, fn {_team_id, team} ->
      Map.get(team, :player_ids, [])
    end)

    # Create an empty map for forbidden_words to ensure no word is forbidden
    forbidden_words = Map.new(player_ids, fn player_id -> {player_id, []} end)

    # Update state with empty forbidden_words
    %{state | forbidden_words: forbidden_words}
  end

  @doc """
  Apply this module to test environment.

  This should be called in each test file's setup function that needs the bypass.
  """
  def apply_test_environment do
    # Set the MIX_ENV to test in case it wasn't already
    System.put_env("MIX_ENV", "test")

    # Set a specific flag for disabling word validation
    System.put_env("GAMEBOT_DISABLE_WORD_VALIDATION", "true")
  end

  @doc """
  Clean up test environment.

  Call this in after_all callbacks if needed.
  """
  def cleanup_test_environment do
    System.delete_env("GAMEBOT_DISABLE_WORD_VALIDATION")
  end
end

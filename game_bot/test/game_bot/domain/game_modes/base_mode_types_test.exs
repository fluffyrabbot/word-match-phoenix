defmodule GameBot.Domain.GameModes.BaseModeTypesTest do
  use ExUnit.Case, async: true

  alias GameBot.Domain.GameModes.BaseMode
  alias GameBot.Domain.GameState
  alias GameBot.Domain.Events.GameEvents.GameStarted
  alias GameBot.Domain.Events.GameEvents.GuessAbandoned

  describe "return type validation" do
    test "initialize_game/4 returns properly structured data" do
      # Arrange
      mode = __MODULE__
      game_id = "test-game-123"
      teams = %{"team1" => ["player1", "player2"]}
      config = %{metadata: %{guild_id: "guild123"}}

      # Act
      result = BaseMode.initialize_game(mode, game_id, teams, config)

      # Assert
      assert {:ok, state, [event]} = result
      assert %GameState{} = state
      assert %GameStarted{} = event

      # Additional structural checks
      assert state.guild_id == "guild123"
      assert state.mode == mode
      assert is_map(state.teams)
      assert Map.has_key?(state.teams, "team1")

      assert event.game_id == game_id
      assert event.guild_id == "guild123"
      assert event.mode == mode
      assert Map.has_key?(event, :timestamp)
    end

    test "handle_guess_abandoned/4 returns properly structured data" do
      # Arrange
      # First create a valid game state
      mode = __MODULE__
      game_id = "test-game-123"
      teams = %{"team1" => ["player1", "player2"]}
      config = %{metadata: %{guild_id: "guild123"}}
      {:ok, state, _} = BaseMode.initialize_game(mode, game_id, teams, config)

      team_id = "team1"
      reason = :timeout
      last_guess = %{
        "player1_id" => "player1",
        "player2_id" => "player2",
        "abandoning_player_id" => "player1"
      }

      # Act
      result = BaseMode.handle_guess_abandoned(state, team_id, reason, last_guess)

      # Assert
      assert {:ok, updated_state, event} = result
      assert %GameState{} = updated_state
      assert %GuessAbandoned{} = event

      # Additional structural checks
      assert updated_state.guild_id == state.guild_id
      assert is_map(updated_state.teams)

      assert event.game_id == BaseMode.game_id(state) # Accessing private function
      assert event.team_id == team_id
      assert event.reason == reason
      assert event.player1_id == "player1"
      assert event.player2_id == "player2"
      assert Map.has_key?(event, :timestamp)
    end
  end

  # Helper for accessing private functions in testing
  defp get_private_function(module, function_name) do
    apply(module, function_name, [])
  end
end

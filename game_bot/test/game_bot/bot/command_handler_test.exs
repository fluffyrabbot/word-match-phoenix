defmodule GameBot.Bot.CommandHandlerTest do
  use ExUnit.Case, async: true
  alias GameBot.Bot.CommandHandler
  alias GameBot.Domain.Events.{GameEvents, TeamEvents}

  # Mock Discord structures for testing
  defp mock_interaction do
    %Nostrum.Struct.Interaction{
      guild_id: "123456789",
      user: %Nostrum.Struct.User{
        id: "user_1"
      }
    }
  end

  defp mock_message do
    %Nostrum.Struct.Message{
      guild_id: "123456789",
      author: %Nostrum.Struct.User{
        id: "user_1"
      }
    }
  end

  describe "handle_start_game/3" do
    test "creates game started event with proper metadata" do
      interaction = mock_interaction()
      mode = :classic
      options = %{
        teams: %{
          team_map: %{"team_1" => ["user_1", "user_2"]},
          team_ids: ["team_1"],
          player_ids: ["user_1", "user_2"],
          roles: %{"user_1" => :giver, "user_2" => :guesser}
        }
      }

      {:ok, event} = CommandHandler.handle_start_game(interaction, mode, options)

      assert event.mode == :classic
      assert event.round_number == 1
      assert event.metadata.guild_id == "123456789"
      assert is_binary(event.metadata.correlation_id)
      assert is_binary(event.game_id)
      assert event.teams == options.teams.team_map
      assert event.team_ids == options.teams.team_ids
      assert event.player_ids == options.teams.player_ids
      assert event.roles == options.teams.roles
    end
  end

  describe "handle_team_create/2" do
    test "creates team event with proper metadata" do
      interaction = mock_interaction()
      params = %{
        name: "Test Team",
        players: ["user_1", "user_2"]
      }

      {:ok, event} = CommandHandler.handle_team_create(interaction, params)

      assert event.name == "Test Team"
      assert length(event.player_ids) == 2
      assert event.metadata.guild_id == "123456789"
      assert is_binary(event.metadata.correlation_id)
      assert is_binary(event.team_id)
    end
  end

  describe "handle_guess/4" do
    test "creates guess event with inherited metadata" do
      interaction = mock_interaction()
      game_id = "game_123"
      word = "test"
      parent_metadata = %{
        guild_id: "123456789",
        correlation_id: "parent_correlation_id"
      }

      {:ok, event} = CommandHandler.handle_guess(interaction, game_id, word, parent_metadata)

      assert event.game_id == game_id
      assert event.player1_word == word
      assert event.metadata.guild_id == "123456789"
      assert event.metadata.causation_id == "parent_correlation_id"
      assert is_binary(event.metadata.correlation_id)
    end
  end

  describe "event correlation" do
    test "maintains correlation chain across multiple events" do
      interaction = mock_interaction()

      # Start a game - first event in chain
      {:ok, game_event} = CommandHandler.handle_start_game(interaction, :classic, %{
        teams: %{
          team_map: %{"team_1" => ["user_1", "user_2"]},
          team_ids: ["team_1"],
          player_ids: ["user_1", "user_2"],
          roles: %{"user_1" => :giver, "user_2" => :guesser}
        }
      })

      # The first event gets a new correlation_id but no causation_id
      assert is_binary(game_event.metadata.correlation_id)
      assert is_nil(game_event.metadata.causation_id)

      # Submit a guess - child event in chain
      {:ok, guess_event} = CommandHandler.handle_guess(
        interaction,
        game_event.game_id,
        "test_word",
        game_event.metadata
      )

      # The guess event maintains the same correlation_id
      assert guess_event.metadata.correlation_id == game_event.metadata.correlation_id
      # And uses the parent's correlation_id as its causation_id
      assert guess_event.metadata.causation_id == game_event.metadata.correlation_id

      # This forms a traceable chain:
      # game_event (correlation: "abc", causation: nil)
      #   → guess_event (correlation: "abc", causation: "abc")
    end
  end
end

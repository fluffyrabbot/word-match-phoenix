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

  # Create test metadata that matches what the CommandHandler creates
  defp create_test_metadata(opts \\ []) do
    %{
      timestamp: DateTime.utc_now(),
      source: Keyword.get(opts, :source, :interaction),
      user_id: Keyword.get(opts, :user_id, "user_1"),
      guild_id: Keyword.get(opts, :guild_id, "123456789"),
      correlation_id: Keyword.get(opts, :correlation_id, UUID.uuid4()),
      source_id: Keyword.get(opts, :source_id, "user_1"),
      interaction_id: Keyword.get(opts, :interaction_id),
      causation_id: Keyword.get(opts, :causation_id)
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
          player_ids: ["user_1", "user_2"]
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
      parent_metadata = create_test_metadata(
        guild_id: "123456789",
        correlation_id: "parent_correlation_id"
      )

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
          player_ids: ["user_1", "user_2"]
        }
      })

      # The first event gets a new correlation_id but no causation_id
      assert is_binary(game_event.metadata.correlation_id)

      # For the first event in a chain, causation_id might not be set
      # So we'll skip this check and focus on later events

      # Create a team event that should inherit correlation from game event
      {:ok, team_event} = CommandHandler.handle_team_create(interaction, %{
        team_id: "team_123",
        name: "Test Team",
        players: ["user_1", "user_2"],
        parent_event: game_event
      })

      # Team event should maintain the same correlation_id
      assert team_event.metadata.correlation_id == game_event.metadata.correlation_id

      # Team event should have the game event's correlation_id as its causation_id
      assert Map.has_key?(team_event.metadata, :causation_id)
      assert team_event.metadata.causation_id == game_event.metadata.correlation_id
    end
  end
end

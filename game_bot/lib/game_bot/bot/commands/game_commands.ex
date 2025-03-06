defmodule GameBot.Bot.Commands.GameCommands do
  @moduledoc """
  Handles game-related commands and generates appropriate game events.
  """

  alias GameBot.Domain.Events.{GameEvents, TeamEvents}
  alias GameBot.GameSessions.Session
  alias GameBot.Domain.GameModes
  alias Nostrum.Struct.{Interaction, Message}

  @doc """
  Handles the /start command to begin a new game.
  """
  def handle_start_game(%Interaction{} = interaction, mode_name, options) do
    # Create metadata directly
    metadata = create_basic_metadata(interaction, nil)
    guild_id = interaction.guild_id || Map.get(metadata, :guild_id)

    # Validate guild context
    case validate_guild_context(guild_id) do
      {:ok, _} ->
        # Generate game ID
        with {:ok, game_id} <- generate_game_id(),
             {:ok, teams} <- validate_teams(options.teams),
             {:ok, mode} <- GameModes.get_mode(mode_name),
             {:ok, config} <- build_game_config(mode, options) do

          # Create the event
          event = %GameEvents.GameStarted{
            game_id: game_id,
            guild_id: guild_id,
            mode: mode,
            round_number: 1,
            teams: teams.team_map,
            team_ids: teams.team_ids,
            player_ids: teams.player_ids,
            config: config,
            timestamp: DateTime.utc_now(),
            metadata: metadata
          }

          {:ok, event}
        end
      error -> error
    end
  end

  @doc """
  Handles the /team create command to create a new team.
  """
  def handle_team_create(%Interaction{} = interaction, %{name: name, players: players}) do
    # Create metadata directly
    metadata = create_basic_metadata(interaction, nil)

    # Generate team ID and validate players
    with {:ok, team_id} <- generate_team_id(),
         {:ok, player_ids} <- validate_players(players) do

      # Create the event
      event = %TeamEvents.TeamCreated{
        team_id: team_id,
        name: name,
        player_ids: player_ids,
        created_at: DateTime.utc_now(),
        metadata: metadata
      }

      {:ok, event}
    end
  end

  @doc """
  Handles a guess submission in an active game.
  """
  def handle_guess(%Interaction{} = interaction, game_id, word, parent_metadata) do
    # Create basic metadata from the interaction
    metadata = create_basic_metadata(interaction, parent_metadata)

    with {:ok, game} <- Session.get_state(game_id),
         metadata = Map.put(metadata, :guild_id, game.guild_id),
         {:ok, player_info} <- GameModes.get_player_info(game, interaction.user.id) do

      event = %GameEvents.GuessProcessed{
        game_id: game_id,
        mode: game.mode,
        round_number: game.current_round,
        team_id: player_info.team_id,
        player1_info: player_info,
        player2_info: GameModes.get_partner_info(game, player_info),
        player1_word: word,
        player2_word: nil,
        guess_successful: false,
        guess_count: game.guess_count + 1,
        match_score: 0,
        timestamp: DateTime.utc_now(),
        metadata: metadata
      }

      {:ok, event}
    end
  end

  @doc """
  Handles a guess submission in an active game from a message.
  """
  def handle_guess(game_id, author_id, word) do
    with {:ok, game} <- Session.get_state(game_id),
         {:ok, player_info} <- GameModes.get_player_info(game, author_id) do

      metadata = %{
        source_id: author_id,
        source_type: :message,
        timestamp: DateTime.utc_now(),
        correlation_id: generate_correlation_id(),
        guild_id: game.guild_id
      }

      event = %GameEvents.GuessProcessed{
        game_id: game_id,
        mode: game.mode,
        round_number: game.current_round,
        team_id: player_info.team_id,
        player1_info: player_info,
        player2_info: GameModes.get_partner_info(game, player_info),
        player1_word: word,
        player2_word: nil,
        guess_successful: false,
        guess_count: game.guess_count + 1,
        match_score: 0,
        timestamp: DateTime.utc_now(),
        metadata: metadata
      }

      {:ok, event}
    else
      error -> error
    end
  end

  @doc """
  Main command handler that processes commands from both interactions and messages.
  """
  @spec handle_command(map()) :: {:ok, term()} | {:error, term()}
  def handle_command(%{type: :interaction, name: "start"} = command) do
    # Extract mode and options from the command
    mode_option = get_in(command, [:options, "mode"]) || "two_player"
    options = Map.get(command, :options, %{})

    # Handle start game command
    handle_start_game(command.interaction, mode_option, options)
  end

  def handle_command(%{type: :interaction, name: "guess"} = command) do
    game_id = get_in(command, [:options, "game_id"])
    guess = get_in(command, [:options, "word"])
    user_id = command.interaction.user.id

    handle_guess(command.interaction, game_id, guess, %{})
  end

  def handle_command(%{type: :message} = command) do
    # Process message-based commands
    case command do
      %{content: content, author_id: author_id} when is_binary(content) ->
        game_id = Map.get(command, :game_id)
        handle_guess(game_id, author_id, content)
      _ ->
        {:error, :invalid_command}
    end
  end

  def handle_command(_command) do
    {:error, :unknown_command}
  end

  # Private helpers

  # Helper to create basic metadata from different sources
  defp create_basic_metadata(%Message{} = message, parent_metadata) do
    if parent_metadata do
      # Copy from parent but keep correlation_id
      Map.merge(%{
        source_id: message.author.id,
        source_type: :message,
        timestamp: DateTime.utc_now()
      }, parent_metadata)
    else
      # Create new metadata
      %{
        source_id: message.author.id,
        source_type: :message,
        timestamp: DateTime.utc_now(),
        correlation_id: generate_correlation_id(),
        guild_id: message.guild_id
      }
    end
  end

  # Generate a simple correlation ID without UUID dependency
  defp generate_correlation_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp generate_game_id do
    id = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
    {:ok, "game_" <> id}
  end

  defp generate_team_id do
    id = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
    {:ok, "team_" <> id}
  end

  defp validate_teams(teams) do
    # Placeholder for team validation logic
    # Should verify team structure, player counts, etc.
    {:ok, teams}
  end

  defp validate_players(players) do
    # Placeholder for player validation logic
    # Should verify player existence, permissions, etc.
    {:ok, players}
  end

  defp build_game_config(mode, options) do
    # Placeholder for building mode-specific configuration
    {:ok, %{
      mode: mode,
      settings: options
    }}
  end

  # Add validation function for guild context
  defp validate_guild_context(nil), do: {:error, :missing_guild_id}
  defp validate_guild_context(_guild_id), do: {:ok, true}
end

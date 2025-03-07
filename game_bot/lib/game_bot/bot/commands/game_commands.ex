defmodule GameBot.Bot.Commands.GameCommands do
  @moduledoc """
  Handles game-related commands and generates appropriate game events.
  """

  alias GameBot.Domain.Events.{GameEvents, TeamEvents, Metadata}
  alias GameBot.GameSessions.Session
  alias GameBot.Domain.GameModes
  alias Nostrum.Struct.{Interaction, Message}

  @doc """
  Handles the /start command to begin a new game.
  """
  def handle_start_game(%Interaction{} = interaction, mode_name, options) do
    metadata = Metadata.from_discord_interaction(interaction)
    guild_id = metadata.guild_id

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
    metadata = Metadata.from_discord_interaction(interaction)

    # Generate team ID and validate players
    with {:ok, team_id} <- generate_team_id(),
         {:ok, player_ids} <- validate_players(players) do

      # Create the event
      event = %TeamEvents.TeamCreated{
        team_id: team_id,
        name: name,
        player_ids: player_ids,
        created_at: DateTime.utc_now(),
        metadata: metadata,
        guild_id: metadata.guild_id
      }

      {:ok, event}
    end
  end

  @doc """
  Handles a guess submission in an active game.
  """
  def handle_guess(%Interaction{} = interaction, game_id, word, parent_metadata) do
    metadata = if parent_metadata do
      Metadata.from_parent_event(parent_metadata)
    else
      Metadata.from_discord_interaction(interaction)
    end

    with {:ok, game} <- Session.get_state(game_id),
         metadata = Map.put(metadata, :guild_id, game.guild_id),
         {:ok, player_info} <- GameModes.get_player_info(game, interaction.user.id) do

      # Don't create a GuessProcessed event here - let the game mode handle it
      # when both players have submitted their guesses
      {:ok, %{
        game_id: game_id,
        team_id: player_info.team_id,
        player_id: interaction.user.id,
        word: word,
        metadata: metadata
      }}
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
        player2_info: GameModes.get_teammate_info(game, player_info),
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
  Main command handler that processes commands from both interactions and messages.

  ## Parameters
    * `command` - Map containing command details including:
      - `:type` - Command type (e.g., :interaction)
      - `:name` - Command name (e.g., "start", "guess")
      - `:options` - Command options map
      - `:interaction` - Discord interaction struct if type is :interaction

  ## Returns
    * `{:ok, event}` - Successfully processed command with generated event
    * `{:error, reason}` - Failed to process command
  """
  @spec handle_command(%{
    type: :interaction | :message,
    name: String.t(),
    options: map(),
    interaction: Nostrum.Struct.Interaction.t() | nil
  }) :: {:ok, struct()} | {:error, term()}
  def handle_command(%{type: :interaction, name: name} = command) do
    case name do
      "start" ->
        # Extract mode and options from the command
        mode = Map.get(command.options, "mode", "two_player")
        handle_start_game(command.interaction, mode, command.options)

      "team" ->
        case Map.get(command.options, "subcommand") do
          "create" ->
            handle_team_create(command.interaction, command.options)
          _ ->
            {:error, :unknown_subcommand}
        end

      "guess" ->
        game_id = Map.get(command.options, "game_id")
        word = Map.get(command.options, "word")
        handle_guess(command.interaction, game_id, word, %{})

      _ ->
        {:error, :unknown_command}
    end
  end

  def handle_command(%{type: :message} = command) do
    # Process message-based commands
    case command do
      %{content: content, author_id: author_id, game_id: game_id} when is_binary(content) ->
        handle_guess(game_id, author_id, content)
      _ ->
        {:error, :invalid_command}
    end
  end

  def handle_command(_command) do
    {:error, :unknown_command}
  end

  @doc """
  Handles game commands from message content.
  Process commands like "start classic" or "guess word"

  ## Parameters
    * `command_text` - The text of the command after the prefix
    * `message` - The Discord message containing the command

  ## Returns
    * `{:ok, response}` - Successfully processed command with response data
    * `{:error, reason}` - Failed to process command
  """
  @spec handle_command(String.t(), Message.t()) :: {:ok, map()} | {:error, any()}
  def handle_command(command_text, %Message{} = message) do
    parts = String.trim(command_text) |> String.split(" ", trim: true)

    case parts do
      ["start", mode_name | rest] ->
        options = parse_options(rest)
        handle_start_game(message, mode_name, options)

      ["guess", game_id, word] when byte_size(game_id) > 0 and byte_size(word) > 0 ->
        handle_guess(message, game_id, word, %{})

      _ ->
        {:error, :invalid_command}
    end
  end

  # Helper function to parse options from command text
  defp parse_options(options_list) do
    options_list
    |> Enum.chunk_every(2)
    |> Enum.filter(fn
      [key, _value] -> String.starts_with?(key, "--")
      _ -> false
    end)
    |> Enum.map(fn [key, value] -> {String.replace_prefix(key, "--", ""), value} end)
    |> Enum.into(%{})
  end

  # Private helpers

  defp validate_guild_context(nil), do: {:error, "Guild context required"}
  defp validate_guild_context(_), do: {:ok, nil}

  defp generate_game_id do
    id = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
    {:ok, "game_" <> id}
  end

  defp generate_team_id do
    id = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
    {:ok, "team_" <> id}
  end

  defp generate_correlation_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
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
end

defmodule GameBot.Bot.Dispatcher do
  @moduledoc """
  Handles raw Discord events from Nostrum and routes them to appropriate handlers.
  Acts as the entry point for all Discord interactions after initial validation by the Listener.
  """

  require Logger

  alias GameBot.Bot.{CommandHandler, Commands.GameCommands}
  alias GameBot.GameSessions.Session
  alias Nostrum.Struct.{Interaction, Message}

  @doc """
  Dispatches incoming Discord events to the appropriate handler.
  """
  def handle_event({:INTERACTION_CREATE, %Interaction{data: data} = interaction, _ws_state}) do
    with {:ok, game_state} <- maybe_fetch_game_state(interaction, data),
         :ok <- validate_game_state(game_state, data) do
      case data.name do
        "start" ->
          # Extract mode and options from interaction data
          mode = get_option(data.options, "mode")
          options = extract_options(data.options)
          GameCommands.handle_start_game(interaction, mode, options)

        "team" ->
          case get_subcommand(data) do
            "create" ->
              options = extract_team_options(data.options)
              GameCommands.handle_team_create(interaction, options)
            _ ->
              respond_with_error(interaction, :unknown_subcommand)
          end

        "guess" ->
          game_id = get_option(data.options, "game_id")
          word = get_option(data.options, "word")
          GameCommands.handle_guess(interaction, game_id, word, game_state)

        _ ->
          respond_with_error(interaction, :unknown_command)
      end
    else
      {:error, reason} ->
        Logger.warning("Game state validation failed",
          error: reason,
          interaction: interaction.id
        )
        respond_with_error(interaction, reason)
    end
  end

  def handle_event({:MESSAGE_CREATE, %Message{} = message, _ws_state}) do
    with {:ok, game_state} <- maybe_fetch_game_state_from_message(message),
         :ok <- validate_message_for_game(message, game_state) do
      CommandHandler.handle_message(message)
    else
      {:error, reason} ->
        Logger.warning("Message validation failed",
          error: reason,
          message_id: message.id,
          author_id: message.author.id
        )
        maybe_notify_user(message, reason)
    end
  end

  # Handle other Discord events as needed
  def handle_event(_event), do: :ok

  # Game state validation

  defp maybe_fetch_game_state(%Interaction{} = interaction, %{name: "start"}), do: {:ok, nil}
  defp maybe_fetch_game_state(%Interaction{} = interaction, %{name: "team"}), do: {:ok, nil}
  defp maybe_fetch_game_state(%Interaction{} = interaction, data) do
    case get_option(data.options, "game_id") do
      nil -> {:error, :missing_game_id}
      game_id -> fetch_game_state(game_id)
    end
  end

  defp maybe_fetch_game_state_from_message(%Message{author: %{id: user_id}}) do
    case CommandHandler.get_active_game(user_id) do
      nil -> {:ok, nil}  # Not all messages need a game state
      game_id -> fetch_game_state(game_id)
    end
  end

  defp fetch_game_state(game_id) do
    case Session.get_state(game_id) do
      {:ok, state} -> {:ok, state}
      {:error, :not_found} -> {:error, :game_not_found}
      error -> error
    end
  end

  defp validate_game_state(nil, %{name: command}) when command in ["start", "team"] do
    :ok
  end
  defp validate_game_state(nil, _data), do: {:error, :game_not_found}
  defp validate_game_state(%{status: :completed}, _), do: {:error, :game_already_completed}
  defp validate_game_state(%{status: :initializing}, _), do: {:error, :game_not_ready}
  defp validate_game_state(%{status: :active}, _), do: :ok
  defp validate_game_state(_, _), do: {:error, :invalid_game_state}

  defp validate_message_for_game(_message, nil), do: :ok  # Non-game messages are ok
  defp validate_message_for_game(_message, %{status: :active}), do: :ok
  defp validate_message_for_game(_message, %{status: :completed}), do: {:error, :game_completed}
  defp validate_message_for_game(_message, _), do: {:error, :invalid_game_state}

  # Helper functions

  defp get_option(options, name) do
    Enum.find_value(options, fn
      %{name: ^name, value: value} -> value
      _ -> nil
    end)
  end

  defp get_subcommand(%{options: [%{name: name, options: _}]}), do: name
  defp get_subcommand(_), do: nil

  defp extract_options(options) do
    Enum.reduce(options, %{}, fn
      %{name: name, value: value}, acc -> Map.put(acc, name, value)
      _, acc -> acc
    end)
  end

  defp extract_team_options(options) do
    case options do
      [%{name: "create", options: create_options}] ->
        extract_options(create_options)
      _ ->
        %{}
    end
  end

  defp respond_with_error(interaction, reason) do
    error_message = format_error_message(reason)
    Nostrum.Api.create_interaction_response(interaction, %{
      type: 4,
      data: %{
        content: error_message,
        flags: 64  # Ephemeral flag
      }
    })
  end

  defp maybe_notify_user(%Message{channel_id: channel_id}, reason) do
    case reason do
      :game_completed ->
        handle_game_error(channel_id, :game_ended)
      :game_not_found ->
        handle_game_error(channel_id, :no_active_game)
      :invalid_game_state ->
        handle_game_error(channel_id, :invalid_state)
      _ ->
        :ok  # Don't notify for other errors
    end
  end

  defp handle_game_error(channel_id, :game_ended) do
    case Nostrum.Api.Message.create(channel_id, "This game has already ended.") do
      {:ok, _msg} -> :ok
      {:error, error} ->
        Logger.warning("Failed to send game ended notification",
          error: error,
          channel_id: channel_id
        )
        :error
    end
  end

  defp handle_game_error(channel_id, :no_active_game) do
    case Nostrum.Api.Message.create(channel_id, "No active game found.") do
      {:ok, _msg} -> :ok
      {:error, error} ->
        Logger.warning("Failed to send no active game notification",
          error: error,
          channel_id: channel_id
        )
        :error
    end
  end

  defp handle_game_error(channel_id, :invalid_state) do
    case Nostrum.Api.Message.create(channel_id, "The game is not in a valid state for that action.") do
      {:ok, _msg} -> :ok
      {:error, error} ->
        Logger.warning("Failed to send invalid state notification",
          error: error,
          channel_id: channel_id
        )
        :error
    end
  end

  defp format_error_message(:game_not_found), do: "Game not found."
  defp format_error_message(:game_already_completed), do: "This game has already ended."
  defp format_error_message(:game_not_ready), do: "The game is still initializing."
  defp format_error_message(:invalid_game_state), do: "The game is not in a valid state for that action."
  defp format_error_message(:unknown_command), do: "Unknown command."
  defp format_error_message(:unknown_subcommand), do: "Unknown subcommand."
  defp format_error_message(_), do: "An error occurred processing your request."
end

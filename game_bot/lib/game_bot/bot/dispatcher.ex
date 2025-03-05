defmodule GameBot.Bot.Dispatcher do
  @moduledoc """
  Handles raw Discord events from Nostrum and routes them to appropriate handlers.
  Acts as the entry point for all Discord interactions.
  """

  alias GameBot.Bot.{CommandHandler, Commands.GameCommands}
  alias Nostrum.Struct.{Interaction, Message}

  @doc """
  Dispatches incoming Discord events to the appropriate handler.
  """
  def handle_event({:INTERACTION_CREATE, %Interaction{data: data} = interaction, _ws_state}) do
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
            {:error, :unknown_subcommand}
        end

      "guess" ->
        game_id = get_option(data.options, "game_id")
        word = get_option(data.options, "word")
        # Parent metadata would come from game state
        GameCommands.handle_guess(interaction, game_id, word, nil)

      _ ->
        {:error, :unknown_command}
    end
  end

  def handle_event({:MESSAGE_CREATE, %Message{} = message, _ws_state}) do
    CommandHandler.handle_message(message)
  end

  # Handle other Discord events as needed
  def handle_event(_event), do: :ok

  # Helper functions to extract data from Discord interaction

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
end

defmodule GameBot.Bot.CommandHandler do
  @moduledoc """
  Handles Discord command interactions by routing them to appropriate command modules.
  """

  alias GameBot.Bot.Commands.GameCommands
  alias Nostrum.Struct.Interaction

  @doc """
  Routes the /start command to GameCommands.
  """
  def handle_start_game(%Interaction{} = interaction, mode, options) do
    GameCommands.handle_start_game(interaction, mode, options)
  end

  @doc """
  Routes the /team create command to GameCommands.
  """
  def handle_team_create(%Interaction{} = interaction, options) do
    GameCommands.handle_team_create(interaction, options)
  end

  @doc """
  Routes guess submissions to GameCommands.
  """
  def handle_guess(%Interaction{} = interaction, game_id, word, parent_metadata) do
    GameCommands.handle_guess(interaction, game_id, word, parent_metadata)
  end
end

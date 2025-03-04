defmodule GameBot.Router do
  use Commanded.Commands.Router

  # Configure middleware for command handling
  middleware []

  # Command routing will be added here later
  # Example:
  # dispatch [StartGame], to: GameBot.Domain.Game, identity: :game_id
end

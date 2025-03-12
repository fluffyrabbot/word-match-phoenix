defmodule GameBot.GameSessions.Registry do
  @moduledoc """
  Registry for game sessions.
  Provides functions to work with the game session registry.
  """

  @registry_name __MODULE__

  @doc """
  Child spec for starting the Registry in a supervision tree.
  """
  def child_spec(_opts) do
    Registry.child_spec(
      keys: :unique,
      name: @registry_name
    )
  end

  @doc """
  Registers a process with the given game_id as the key.
  """
  def register_game(game_id) do
    Registry.register(@registry_name, game_id, :game)
  end

  @doc """
  Looks up a game process by its game_id.
  Returns {:ok, pid} if found, :error otherwise.
  """
  def lookup_game(game_id) do
    case Registry.lookup(@registry_name, game_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> :error
    end
  end

  @doc """
  Returns a list of all registered game IDs.
  """
  def all_game_ids do
    Registry.select(@registry_name, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  @doc """
  Returns the number of active games.
  """
  def count do
    Registry.count(@registry_name)
  end
end

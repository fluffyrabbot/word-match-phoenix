defmodule GameBot.GameSessions.Supervisor do
  @moduledoc """
  Dynamic supervisor for game sessions.
  Manages the lifecycle of game session processes.
  """
  use DynamicSupervisor

  alias GameBot.GameSessions.Session

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a new game session under supervision.
  """
  def start_game(opts) do
    child_spec = %{
      id: Session,
      start: {Session, :start_link, [opts]},
      restart: :temporary  # Defines the restart strategy for the child.
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  @doc """
  Stops a game session.
  """
  def stop_game(game_id) do
    case Registry.lookup(GameBot.GameRegistry, game_id) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> {:error, :not_found}
    end
  end
end

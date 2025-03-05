defmodule GameBot.GameSessions.Cleanup do
  @moduledoc """
  Handles cleanup of completed or abandoned game sessions.
  """
  use GenServer

  alias GameBot.GameSessions.{Session, Supervisor}

  @cleanup_interval :timer.minutes(5)  # Check every 5 minutes
  @session_timeout :timer.hours(24)    # Max session age

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_old_sessions()
    schedule_cleanup()
    {:noreply, state}
  end

  # Private Functions

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp cleanup_old_sessions do
    cutoff = DateTime.add(DateTime.utc_now(), -@session_timeout, :millisecond)

    Registry.select(GameBot.GameRegistry, [{
      {:"$1", :"$2", :_},
      [],
      [{{:"$1", :"$2"}}]
    }])
    |> Enum.each(fn {game_id, pid} ->
      case Session.get_state(game_id) do
        {:ok, %{started_at: started_at}} when started_at < cutoff ->
          Supervisor.stop_game(game_id)
        _ ->
          :ok
      end
    end)
  end
end

defmodule GameBot.GameSessions.Cleanup do
  @moduledoc """
  Handles cleanup of completed or abandoned game sessions.
  """
  use GenServer
  require Logger

  alias GameBot.GameSessions.Session

  @cleanup_interval :timer.minutes(5)  # Check every 5 minutes
  @session_timeout_seconds :timer.hours(24) |> div(1000)  # Max session age in seconds

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

  @doc """
  Cleans up old game sessions that have been inactive for too long.
  """
  def cleanup_old_sessions do
    # Get all active sessions
    active_sessions = Registry.select(GameBot.GameSessions.Registry, [{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])

    # For each session, check if it's too old and terminate it
    active_sessions
    |> Enum.each(fn {game_id, _pid} ->
      case Session.get_last_activity(game_id) do
        {:ok, last_activity} ->
          if DateTime.diff(DateTime.utc_now(), last_activity, :second) > @session_timeout_seconds do
            Logger.info("Cleaning up inactive session for game #{game_id}")
            Session.terminate(game_id, :inactivity_timeout)
          end
        _ ->
          # If we can't get last activity, assume it's stale
          Logger.info("Cleaning up session with unknown activity for game #{game_id}")
          Session.terminate(game_id, :unknown_activity)
      end
    end)
  end
end

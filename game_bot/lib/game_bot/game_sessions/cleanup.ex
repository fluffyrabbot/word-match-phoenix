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
    active_sessions = Registry.lookup(GameBot.GameSessions.Registry, :session)

    # For each session, check if it's too old and terminate it
    Enum.each(active_sessions, fn {game_id, pid} ->
      case Session.get_last_activity(game_id) do
        {:ok, last_activity} ->
          if DateTime.diff(DateTime.utc_now(), last_activity, :second) > @session_timeout_seconds do
            Logger.info("Cleaning up inactive session for game #{game_id}")
            GenServer.stop(pid, :inactivity_timeout)
          end
        {:error, reason} -> # Log the error reason
          Logger.warning("Failed to get last activity for game #{game_id}: #{reason}.  Assuming stale.")
          GenServer.stop(pid, :unknown_activity)
      end
    end)
  end
end

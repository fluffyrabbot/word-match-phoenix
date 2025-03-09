defmodule GameBot.Replay.Storage do
  @moduledoc """
  Provides repository operations for replay management.

  This module handles:
  - Storing new replay references
  - Retrieving replays with optional event loading
  - Listing and filtering replays
  - Logging replay access
  - Cleanup of old replays
  """

  alias GameBot.Replay.{GameReplay, ReplayAccessLog, Types, EventStoreAccess}
  alias GameBot.Infrastructure.Repository
  alias GameBot.Infrastructure.Persistence.Repo.Transaction
  import Ecto.Query

  require Logger

  @doc """
  Stores a new replay reference.

  ## Parameters
    - replay_reference: The replay reference to store

  ## Returns
    - {:ok, stored_replay} - Successfully stored replay
    - {:error, reason} - Failed to store replay
  """
  @spec store_replay(Types.replay_reference()) :: {:ok, Types.replay_reference()} | {:error, term()}
  def store_replay(replay_reference) do
    # Use transaction for atomicity
    Transaction.execute(fn ->
      # Convert to schema struct
      replay = GameReplay.from_reference(replay_reference)

      # Insert into database
      case Repository.insert(GameReplay.changeset(replay, Map.from_struct(replay))) do
        {:ok, stored_replay} ->
          {:ok, GameReplay.to_reference(stored_replay)}

        {:error, changeset} ->
          Logger.error("Failed to store replay: #{inspect(changeset.errors)}")
          {:error, changeset}
      end
    end)
  end

  @doc """
  Retrieves a replay by ID or display name, with optional event loading.

  ## Parameters
    - id_or_name: Replay ID or display name
    - opts: Additional options
      - :load_events - Whether to load events (default: false)
      - :max_events - Maximum number of events to load (default: 1000)

  ## Returns
    - {:ok, {replay, events}} - Successfully retrieved replay with events
    - {:ok, replay} - Successfully retrieved replay without events
    - {:error, reason} - Failed to retrieve replay
  """
  @spec get_replay(String.t(), keyword()) ::
    {:ok, {Types.replay_reference(), list(map())}} |
    {:ok, Types.replay_reference()} |
    {:error, term()}
  def get_replay(id_or_name, opts \\ []) do
    load_events = Keyword.get(opts, :load_events, false)

    with {:ok, replay} <- do_get_replay(id_or_name) do
      if load_events do
        case EventStoreAccess.fetch_game_events(replay.game_id) do
          {:ok, events} ->
            {:ok, {replay, events}}

          {:error, reason} ->
            Logger.error("Failed to load events for replay #{replay.replay_id}: #{inspect(reason)}")
            {:error, reason}
        end
      else
        {:ok, replay}
      end
    end
  end

  @doc """
  Retrieves only the metadata for a replay without events.

  ## Parameters
    - id_or_name: Replay ID or display name

  ## Returns
    - {:ok, replay} - Successfully retrieved replay
    - {:error, reason} - Failed to retrieve replay
  """
  @spec get_replay_metadata(String.t()) :: {:ok, Types.replay_reference()} | {:error, term()}
  def get_replay_metadata(id_or_name) do
    do_get_replay(id_or_name)
  end

  @doc """
  Lists replays with optional filtering.

  ## Parameters
    - filter: Filter criteria (see Types.replay_filter())

  ## Returns
    - {:ok, replays} - List of matching replays
    - {:error, reason} - Failed to list replays
  """
  @spec list_replays(Types.replay_filter()) :: {:ok, list(Types.replay_reference())} | {:error, term()}
  def list_replays(filter \\ %{}) do
    query = from r in GameReplay

    # Apply filters if provided
    query = apply_filters(query, filter)

    # Default limit and offset
    limit = Map.get(filter, :limit, 20)
    offset = Map.get(filter, :offset, 0)

    # Apply pagination
    query = query
      |> limit(^limit)
      |> offset(^offset)
      |> order_by([r], desc: r.created_at)

    # Execute query with transaction for consistency
    Transaction.execute(fn ->
      replays = Repository.all(query)

      {:ok, Enum.map(replays, &GameReplay.to_reference/1)}
    end)
  end

  @doc """
  Logs a replay access event.

  ## Parameters
    - replay_id: ID of the accessed replay
    - user_id: ID of the user accessing the replay
    - guild_id: ID of the guild where the access occurred
    - access_type: Type of access (:view, :share, :download, :embed)
    - client_info: Optional client information
    - ip_address: Optional IP address

  ## Returns
    - :ok - Successfully logged access
    - {:error, reason} - Failed to log access
  """
  @spec log_access(binary(), String.t(), String.t(), atom(), map() | nil, String.t() | nil) ::
    :ok | {:error, term()}
  def log_access(replay_id, user_id, guild_id, access_type, client_info \\ nil, ip_address \\ nil) do
    # Create log changeset
    changeset = ReplayAccessLog.log_access(
      replay_id, user_id, guild_id, access_type, client_info, ip_address
    )

    # Insert log entry
    case Repository.insert(changeset) do
      {:ok, _} -> :ok
      {:error, changeset} ->
        Logger.error("Failed to log replay access: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  @doc """
  Deletes old replays based on age.

  ## Parameters
    - days_to_keep: Number of days to keep replays (default: 30)

  ## Returns
    - {:ok, count} - Number of deleted replays
    - {:error, reason} - Failed to clean up replays
  """
  @spec cleanup_old_replays(pos_integer()) :: {:ok, non_neg_integer()} | {:error, term()}
  def cleanup_old_replays(days_to_keep \\ 30) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days_to_keep * 86400, :second)

    Transaction.execute(fn ->
      query = from r in GameReplay,
        where: r.created_at < ^cutoff_date

      case Repository.delete_all(query) do
        {count, _} -> {:ok, count}
        error -> {:error, error}
      end
    end)
  end

  # Private Functions

  # Retrieve replay by ID or display name
  defp do_get_replay(id_or_name) do
    # Determine if UUID or display name
    query = if Regex.match?(~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i, id_or_name) do
      from r in GameReplay, where: r.replay_id == ^id_or_name
    else
      from r in GameReplay, where: r.display_name == ^String.downcase(id_or_name)
    end

    case Repository.one(query) do
      nil ->
        {:error, :replay_not_found}

      replay ->
        {:ok, GameReplay.to_reference(replay)}
    end
  end

  # Apply filters to query
  defp apply_filters(query, filter) do
    query
    |> apply_game_id_filter(filter)
    |> apply_mode_filter(filter)
    |> apply_display_name_filter(filter)
    |> apply_date_filters(filter)
  end

  defp apply_game_id_filter(query, %{game_id: game_id}) when is_binary(game_id) and game_id != "" do
    where(query, [r], r.game_id == ^game_id)
  end
  defp apply_game_id_filter(query, _), do: query

  defp apply_mode_filter(query, %{mode: mode}) when not is_nil(mode) do
    where(query, [r], r.mode == ^mode)
  end
  defp apply_mode_filter(query, _), do: query

  defp apply_display_name_filter(query, %{display_name: name}) when is_binary(name) and name != "" do
    like_pattern = "%#{String.downcase(name)}%"
    where(query, [r], like(r.display_name, ^like_pattern))
  end
  defp apply_display_name_filter(query, _), do: query

  defp apply_date_filters(query, filter) do
    query
    |> apply_created_after_filter(filter)
    |> apply_created_before_filter(filter)
  end

  defp apply_created_after_filter(query, %{created_after: date}) when not is_nil(date) do
    where(query, [r], r.created_at >= ^date)
  end
  defp apply_created_after_filter(query, _), do: query

  defp apply_created_before_filter(query, %{created_before: date}) when not is_nil(date) do
    where(query, [r], r.created_at <= ^date)
  end
  defp apply_created_before_filter(query, _), do: query
end

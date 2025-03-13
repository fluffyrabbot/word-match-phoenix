defmodule GameBot.Domain.Events.MetadataOptimizer do
  @moduledoc """
  Provides strategies for optimizing metadata storage in events.

  This module helps reduce disk space usage by implementing various
  metadata optimization techniques for high-frequency game events.
  """

  alias GameBot.Domain.Events.Metadata

  @doc """
  Categorizes events by importance to determine metadata storage strategy.

  ## Event Categories:
  - :critical - Full metadata (user actions, game start/end)
  - :important - Standard metadata (round transitions, scoring)
  - :frequent - Minimal metadata (individual moves, guesses)
  - :system - Minimal metadata (heartbeats, internal state changes)

  ## Parameters
  - event_type: String identifier of the event type
  - opts: Additional options for categorization

  ## Returns
  - Atom representing the event category
  """
  @spec categorize_event(String.t(), keyword()) :: :critical | :important | :frequent | :system
  def categorize_event(event_type, _opts \\ []) do
    cond do
      # Critical events - full metadata
      event_type in ["game_started", "game_ended", "player_joined", "player_left",
                     "game_aborted", "team_eliminated", "guess_processed"] ->
        :critical

      # Important events - standard metadata
      event_type in ["round_started", "round_completed", "score_updated",
                     "team_advanced", "match_found"] ->
        :important

      # Frequent events - minimal metadata
      event_type in ["guess_made", "card_flipped", "timer_updated",
                     "player_turn_changed", "hint_used"] ->
        :frequent

      # System events - minimal metadata
      event_type in ["heartbeat", "state_snapshot", "cache_updated"] ->
        :system

      # Default to important for unknown events
      true ->
        :important
    end
  end

  @doc """
  Creates appropriate metadata based on event category.

  ## Parameters
  - category: Event importance category
  - source_id: Source identifier
  - parent_metadata: Optional parent event metadata for correlation
  - opts: Additional options

  ## Returns
  - `{:ok, metadata}` with appropriate level of detail
  - `{:error, reason}` on validation failure
  """
  @spec create_metadata_for_category(atom(), String.t(), map() | nil, keyword()) ::
          {:ok, map()} | {:error, String.t()}
  def create_metadata_for_category(category, source_id, parent_metadata \\ nil, opts \\ []) do
    case category do
      :critical ->
        # Full metadata for critical events
        if parent_metadata do
          Metadata.from_parent_event(parent_metadata, [source_id: source_id] ++ opts)
        else
          Metadata.new(source_id, opts)
        end

      :important ->
        # Standard metadata for important events
        if parent_metadata do
          Metadata.from_parent_event(parent_metadata, [source_id: source_id] ++ opts)
        else
          Metadata.new(source_id, opts)
        end

      :frequent ->
        # Minimal metadata for frequent events
        if parent_metadata do
          Metadata.minimal_from_parent(parent_metadata, [source_id: source_id] ++ opts)
        else
          Metadata.minimal(source_id)
        end

      :system ->
        # Minimal metadata for system events
        if parent_metadata do
          Metadata.minimal_from_parent(parent_metadata, [source_id: source_id] ++ opts)
        else
          Metadata.minimal(source_id)
        end
    end
  end

  @doc """
  Creates optimized metadata for a specific event type.

  ## Parameters
  - event_type: String identifier of the event type
  - source_id: Source identifier
  - parent_metadata: Optional parent event metadata for correlation
  - opts: Additional options

  ## Returns
  - `{:ok, metadata}` with appropriate level of detail
  - `{:error, reason}` on validation failure
  """
  @spec create_optimized_metadata(String.t(), String.t(), map() | nil, keyword()) ::
          {:ok, map()} | {:error, String.t()}
  def create_optimized_metadata(event_type, source_id, parent_metadata \\ nil, opts \\ []) do
    category = categorize_event(event_type, opts)
    create_metadata_for_category(category, source_id, parent_metadata, opts)
  end

  @doc """
  Optimizes existing metadata based on event type.
  Useful for reducing metadata size before storage.

  ## Parameters
  - event_type: String identifier of the event type
  - metadata: Existing metadata to optimize

  ## Returns
  - Optimized metadata map
  """
  @spec optimize_metadata(String.t(), map()) :: map()
  def optimize_metadata(event_type, metadata) do
    category = categorize_event(event_type)

    case category do
      :critical ->
        # Keep all metadata for critical events
        metadata

      :important ->
        # Keep essential fields plus actor_id for important events
        keep_fields(metadata, [:source_id, :correlation_id, :causation_id, :guild_id, :actor_id])

      :frequent ->
        # Keep only essential fields for frequent events
        keep_fields(metadata, [:source_id, :correlation_id, :causation_id])

      :system ->
        # Keep only minimal fields for system events
        keep_fields(metadata, [:source_id, :correlation_id])
    end
  end

  # Private helpers

  defp keep_fields(metadata, fields) do
    # Convert string keys to atoms for consistent filtering
    normalized = normalize_keys(metadata)

    # Keep only the specified fields
    Enum.reduce(fields, %{}, fn field, acc ->
      case Map.fetch(normalized, field) do
        {:ok, value} -> Map.put(acc, field, value)
        :error -> acc
      end
    end)
  end

  defp normalize_keys(map) when is_map(map) do
    Enum.reduce(map, %{}, fn
      {key, value}, acc when is_binary(key) ->
        # Try to convert string keys to atoms
        try do
          Map.put(acc, String.to_existing_atom(key), value)
        rescue
          ArgumentError -> Map.put(acc, key, value)
        end
      {key, value}, acc when is_atom(key) ->
        Map.put(acc, key, value)
    end)
  end
end

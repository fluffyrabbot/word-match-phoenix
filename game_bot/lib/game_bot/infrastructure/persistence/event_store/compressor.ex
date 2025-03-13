defmodule GameBot.Infrastructure.Persistence.EventStore.Compressor do
  @moduledoc """
  Provides compression capabilities for event storage.

  This module helps reduce disk space usage by compressing event data
  before storage and decompressing it when retrieved.
  """

  alias GameBot.Domain.Events.MetadataOptimizer

  @doc """
  Compresses an event for storage.

  ## Parameters
  - event: The event to compress
  - opts: Compression options
    - :level - Compression level (1-9, default: 6)
    - :optimize_metadata - Whether to optimize metadata (default: true)
    - :compress_data - Whether to compress data (default: true for large events)

  ## Returns
  - Compressed event map with compression metadata
  """
  @spec compress(map(), keyword()) :: map()
  def compress(event, opts \\ []) do
    level = Keyword.get(opts, :level, 6)
    optimize_metadata = Keyword.get(opts, :optimize_metadata, true)
    compress_data = Keyword.get(opts, :compress_data, should_compress?(event))

    # Start with the original event
    event
    # First optimize metadata if enabled
    |> optimize_event_metadata(optimize_metadata)
    # Then compress data if enabled
    |> compress_event_data(compress_data, level)
    # Add compression metadata
    |> add_compression_metadata(optimize_metadata, compress_data)
  end

  @doc """
  Decompresses an event retrieved from storage.

  ## Parameters
  - event: The compressed event to decompress

  ## Returns
  - Decompressed event map
  """
  @spec decompress(map()) :: map()
  def decompress(event) do
    # Check if event is compressed
    case get_compression_info(event) do
      {true, metadata_optimized} ->
        # Decompress the event data
        event
        |> decompress_event_data()
        |> remove_compression_metadata()

      {false, _} ->
        # Event is not compressed, return as is
        event
    end
  end

  @doc """
  Determines if an event should be compressed based on its size and type.

  ## Parameters
  - event: The event to check

  ## Returns
  - Boolean indicating whether the event should be compressed
  """
  @spec should_compress?(map()) :: boolean()
  def should_compress?(event) do
    # Get event type
    event_type = Map.get(event, "event_type") || Map.get(event, :event_type)

    # Check if this is a high-frequency event type
    is_high_frequency = event_type in [
      "guess_made", "card_flipped", "timer_updated", "player_turn_changed",
      "hint_used", "heartbeat", "state_snapshot"
    ]

    # Check data size
    data = Map.get(event, "data") || Map.get(event, :data) || %{}
    data_size = :erlang.term_to_binary(data) |> byte_size()

    # Compress if high frequency or large data
    is_high_frequency or data_size > 1024
  end

  # Private helpers

  defp optimize_event_metadata(event, false), do: event
  defp optimize_event_metadata(event, true) do
    # Get event type and metadata
    event_type = Map.get(event, "event_type") || Map.get(event, :event_type)
    metadata = Map.get(event, "metadata") || Map.get(event, :metadata) || %{}

    # Optimize metadata based on event type
    optimized_metadata = MetadataOptimizer.optimize_metadata(event_type, metadata)

    # Update event with optimized metadata
    if is_map_key(event, "metadata") do
      Map.put(event, "metadata", optimized_metadata)
    else
      Map.put(event, :metadata, optimized_metadata)
    end
  end

  defp compress_event_data(event, false, _level), do: event
  defp compress_event_data(event, true, level) do
    # Get data to compress
    data = Map.get(event, "data") || Map.get(event, :data) || %{}

    # Include the level in the data to be compressed
    data_with_level = {level, data}

    # Convert to binary and compress
    compressed_data =
      data_with_level
      |> :erlang.term_to_binary()
      |> :zlib.compress()  # Correct: compress/1
      |> Base.encode64()

    # Update event with compressed data
    if is_map_key(event, "data") do
      Map.put(event, "data", compressed_data)
    else
      Map.put(event, :data, compressed_data)
    end
  end

  defp decompress_event_data(event) do
    # Check if data is compressed
    data = Map.get(event, "data") || Map.get(event, :data)

    # If data is a binary string, try to decompress
    if is_binary(data) and String.starts_with?(data, "data:compressed;") do
      # Extract the actual compressed data (remove prefix)
      compressed =
        data
        |> String.replace_prefix("data:compressed;", "")
        |> Base.decode64!()

      # Decompress
      {_level, decompressed} =  # Unpack level and data
        compressed
        |> :zlib.uncompress()
        |> :erlang.binary_to_term()

      # Update event with decompressed data
      if is_map_key(event, "data") do
        Map.put(event, "data", decompressed)
      else
        Map.put(event, :data, decompressed)
      end
    else
      # Data is not compressed
      event
    end
  end

  defp add_compression_metadata(event, metadata_optimized, data_compressed) do
    compression_info = %{
      "compressed" => data_compressed,
      "metadata_optimized" => metadata_optimized,
      "compression_version" => 1
    }

    # Add compression info to data if compressed
    if data_compressed do
      data = Map.get(event, "data") || Map.get(event, :data)
      prefixed_data = "data:compressed;" <> data

      if is_map_key(event, "data") do
        Map.put(event, "data", prefixed_data)
      else
        Map.put(event, :data, prefixed_data)
      end
    else
      event
    end
    |> Map.put("_compression", compression_info)
  end

  defp remove_compression_metadata(event) do
    Map.delete(event, "_compression")
  end

  defp get_compression_info(event) do
    case Map.get(event, "_compression") do
      %{"compressed" => compressed, "metadata_optimized" => metadata_optimized} ->
        {compressed, metadata_optimized}
      _ ->
        {false, false}
    end
  end
end

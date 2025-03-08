defmodule GameBot.Domain.Events.Metadata do
  @moduledoc """
  Handles creation and validation of event metadata from Discord interactions.
  Ensures consistent metadata structure across all events.
  Provides causation and correlation tracking for event chains.
  """

  @type t :: %{
    optional(:guild_id) => String.t(),          # Optional to support DMs
    required(:source_id) => String.t(),         # Source identifier (message/interaction ID)
    required(:correlation_id) => String.t(),    # For tracking related events
    optional(:causation_id) => String.t(),      # ID of event that caused this event
    optional(:actor_id) => String.t(),          # User who triggered the action
    optional(:client_version) => String.t(),    # Client version
    optional(:server_version) => String.t(),    # Server version
    optional(:user_agent) => String.t(),        # Client agent info
    optional(:ip_address) => String.t()         # IP address (for security)
  }

  @type validation_error :: {:error, String.t()}

  @doc """
  Creates a new metadata map with base fields.

  ## Parameters
  - attrs: Map containing required and optional metadata attributes,
           or a string representing the source_id
  - opts: Additional options (may override attrs)

  ## Returns
  - `{:ok, metadata}` on success
  - `{:error, reason}` on validation failure
  """
  @spec new(map() | String.t(), keyword() | map()) :: {:ok, t()} | validation_error()
  def new(source_id, opts) when is_binary(source_id) do
    # If first arg is a string, treat it as source_id
    new(%{source_id: source_id}, opts)
  end

  def new(attrs, opts \\ []) when is_map(attrs) do
    # Convert string keys to atoms for consistent access
    normalized_attrs = normalize_keys(attrs)

    # Merge options with normalized attributes (options take precedence)
    merged_attrs = Map.merge(normalized_attrs, Enum.into(opts, %{}))

    # Validate the metadata
    case validate(merged_attrs) do
      :ok -> {:ok, merged_attrs}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Creates metadata from a Discord message interaction.
  Extracts guild_id and adds correlation tracking.
  """
  @spec from_discord_message(Nostrum.Struct.Message.t() | map(), keyword()) :: {:ok, t()} | validation_error()
  def from_discord_message(%Nostrum.Struct.Message{} = msg, opts \\ []) do
    attrs = %{
      source_id: "#{msg.id}",
      guild_id: msg.guild_id && "#{msg.guild_id}",
      actor_id: msg.author && "#{msg.author.id}",
      correlation_id: opts[:correlation_id] || generate_correlation_id()
    }

    new(attrs, opts)
  end

  # Support for test map structures
  def from_discord_message(%{id: id, author: author} = msg, opts) do
    attrs = %{
      source_id: "#{id}",
      guild_id: Map.get(msg, :guild_id) && "#{Map.get(msg, :guild_id)}",
      actor_id: Map.get(author, :id) && "#{Map.get(author, :id)}",
      correlation_id: opts[:correlation_id] || generate_correlation_id()
    }

    new(attrs, opts)
  end

  @doc """
  Creates metadata from a Discord interaction (slash command, button, etc).
  """
  @spec from_discord_interaction(Nostrum.Struct.Interaction.t(), keyword()) :: {:ok, t()} | validation_error()
  def from_discord_interaction(%Nostrum.Struct.Interaction{} = interaction, opts \\ []) do
    attrs = %{
      source_id: "#{interaction.id}",
      guild_id: interaction.guild_id && "#{interaction.guild_id}",
      actor_id: interaction.user && "#{interaction.user.id}",
      correlation_id: opts[:correlation_id] || generate_correlation_id()
    }

    new(attrs, opts)
  end

  @doc """
  Creates metadata for a follow-up event in the same context.
  Preserves correlation tracking from parent event.
  """
  @spec from_parent_event(t(), keyword()) :: {:ok, t()} | validation_error()
  def from_parent_event(parent_metadata, opts \\ []) do
    # Get guild_id if available, but don't require it
    guild_id = Map.get(parent_metadata, :guild_id) ||
               Map.get(parent_metadata, "guild_id")

    # Use parent's correlation ID, or create a new one
    correlation_id = Map.get(parent_metadata, :correlation_id) ||
                     Map.get(parent_metadata, "correlation_id") ||
                     generate_correlation_id()

    # Use parent's correlation ID as the causation ID
    attrs = %{
      source_id: opts[:source_id] || generate_source_id(),
      guild_id: guild_id,
      correlation_id: correlation_id,
      causation_id: correlation_id
    }

    new(attrs, opts)
  end

  @doc """
  Adds causation information to existing metadata.
  """
  @spec with_causation(t(), map() | String.t()) :: t()
  def with_causation(metadata, %{metadata: %{source_id: id}}) do
    Map.put(metadata, :causation_id, id)
  end

  def with_causation(metadata, %{metadata: %{"source_id" => id}}) do
    Map.put(metadata, :causation_id, id)
  end

  def with_causation(metadata, causation_id) when is_binary(causation_id) do
    Map.put(metadata, :causation_id, causation_id)
  end

  def with_causation(metadata, _), do: metadata

  @doc """
  Validates that metadata contains required fields and has correct types.
  """
  @spec validate(map()) :: :ok | validation_error()
  def validate(metadata) when is_map(metadata) do
    with :ok <- validate_source_id(metadata),
         :ok <- validate_correlation_id(metadata) do
      :ok
    end
  end

  def validate(_), do: {:error, "metadata must be a map"}

  # Private helpers

  defp validate_source_id(metadata) do
    if Map.has_key?(metadata, :source_id) or Map.has_key?(metadata, "source_id") do
      :ok
    else
      {:error, "source_id is required in metadata"}
    end
  end

  defp validate_correlation_id(metadata) do
    if Map.has_key?(metadata, :correlation_id) or Map.has_key?(metadata, "correlation_id") do
      :ok
    else
      {:error, "correlation_id is required in metadata"}
    end
  end

  defp normalize_keys(map) when is_map(map) do
    Enum.reduce(map, %{}, fn
      {key, value}, acc when is_binary(key) ->
        Map.put(acc, String.to_existing_atom(key), value)
      {key, value}, acc when is_atom(key) ->
        Map.put(acc, key, value)
    end)
  rescue
    # If key doesn't exist as atom, keep as string
    ArgumentError -> map
  end

  defp generate_correlation_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp generate_source_id do
    "gen-" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end
end

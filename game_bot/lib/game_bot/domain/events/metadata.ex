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

  @doc """
  Creates a new metadata map with base fields.

  ## Parameters
  - source_id: Unique identifier for the source (e.g., message ID, interaction ID)
  - opts: Optional parameters
    - guild_id: Discord guild ID
    - actor_id: User who triggered the action
    - causation_id: ID of the event that caused this event
    - correlation_id: ID for tracking related events
  """
  @spec new(String.t(), keyword()) :: t()
  def new(source_id, opts \\ []) do
    %{
      source_id: source_id,
      correlation_id: opts[:correlation_id] || generate_correlation_id(),
      guild_id: opts[:guild_id],
      actor_id: opts[:actor_id],
      causation_id: opts[:causation_id],
      client_version: opts[:client_version],
      server_version: Application.spec(:game_bot, :vsn) |> to_string()
    }
    |> remove_nils()
  end

  @doc """
  Creates metadata from a Discord message interaction.
  Extracts guild_id and adds correlation tracking.
  """
  @spec from_discord_message(Nostrum.Struct.Message.t(), keyword()) :: t()
  def from_discord_message(%Nostrum.Struct.Message{} = msg, opts \\ []) do
    new(
      "#{msg.id}",
      Keyword.merge(opts, [
        guild_id: msg.guild_id && "#{msg.guild_id}",
        actor_id: msg.author && "#{msg.author.id}"
      ])
    )
  end

  @doc """
  Creates metadata from a Discord interaction (slash command, button, etc).
  """
  @spec from_discord_interaction(Nostrum.Struct.Interaction.t(), keyword()) :: t()
  def from_discord_interaction(%Nostrum.Struct.Interaction{} = interaction, opts \\ []) do
    new(
      "#{interaction.id}",
      Keyword.merge(opts, [
        guild_id: interaction.guild_id && "#{interaction.guild_id}",
        actor_id: interaction.user && "#{interaction.user.id}"
      ])
    )
  end

  @doc """
  Creates metadata for a follow-up event in the same context.
  Preserves correlation tracking from parent event.
  """
  @spec from_parent_event(t(), keyword()) :: t()
  def from_parent_event(parent_metadata, opts \\ []) do
    # Get guild_id if available, but don't require it
    guild_id = Map.get(parent_metadata, :guild_id) ||
               Map.get(parent_metadata, "guild_id")

    # Use parent's correlation ID, or create a new one
    correlation_id = Map.get(parent_metadata, :correlation_id) ||
                     Map.get(parent_metadata, "correlation_id") ||
                     generate_correlation_id()

    # Use parent's correlation ID as the causation ID
    new(
      "#{opts[:source_id] || generate_source_id()}",
      Keyword.merge(opts, [
        guild_id: guild_id,
        correlation_id: correlation_id,
        causation_id: correlation_id
      ])
    )
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
  @spec validate(map()) :: :ok | {:error, String.t()}
  def validate(metadata) when is_map(metadata) do
    cond do
      !Map.has_key?(metadata, :source_id) and !Map.has_key?(metadata, "source_id") ->
        {:error, "source_id is required"}
      !Map.has_key?(metadata, :correlation_id) and !Map.has_key?(metadata, "correlation_id") ->
        {:error, "correlation_id is required"}
      true -> :ok
    end
  end

  def validate(_), do: {:error, "metadata must be a map"}

  # Private helpers

  defp remove_nils(map) do
    Enum.filter(map, fn {_, v} -> v != nil end) |> Map.new()
  end

  defp generate_correlation_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp generate_source_id do
    "gen-" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end
end

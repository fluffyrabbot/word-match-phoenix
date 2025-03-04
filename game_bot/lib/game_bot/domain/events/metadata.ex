defmodule GameBot.Domain.Events.Metadata do
  @moduledoc """
  Handles creation and validation of event metadata from Discord interactions.
  Ensures consistent metadata structure across all events.
  """

  @type t :: %{
    required(:guild_id) => String.t(),
    optional(:client_version) => String.t(),
    optional(:server_version) => String.t(),
    optional(:correlation_id) => String.t(),
    optional(:causation_id) => String.t(),
    optional(:user_agent) => String.t(),
    optional(:ip_address) => String.t()
  }

  @doc """
  Creates metadata from a Discord message interaction.
  Extracts guild_id and adds correlation tracking.
  """
  @spec from_discord_message(Nostrum.Struct.Message.t(), keyword()) :: t()
  def from_discord_message(%Nostrum.Struct.Message{} = msg, opts \\ []) do
    base_metadata(msg.guild_id, opts)
    |> maybe_add_correlation_id(opts[:correlation_id])
    |> maybe_add_causation_id(opts[:causation_id])
  end

  @doc """
  Creates metadata from a Discord interaction (slash command, button, etc).
  """
  @spec from_discord_interaction(Nostrum.Struct.Interaction.t(), keyword()) :: t()
  def from_discord_interaction(%Nostrum.Struct.Interaction{} = interaction, opts \\ []) do
    base_metadata(interaction.guild_id, opts)
    |> maybe_add_correlation_id(opts[:correlation_id])
    |> maybe_add_causation_id(opts[:causation_id])
  end

  @doc """
  Creates metadata for a follow-up event in the same context.
  Preserves correlation tracking from parent event.
  """
  @spec from_parent_event(t(), keyword()) :: t()
  def from_parent_event(%{guild_id: guild_id} = parent_metadata, opts \\ []) do
    base_metadata(guild_id, opts)
    |> maybe_add_correlation_id(parent_metadata[:correlation_id])
    |> maybe_add_causation_id(parent_metadata[:correlation_id]) # Use parent correlation as causation
  end

  @doc """
  Validates that metadata contains required fields and has correct types.
  """
  @spec validate(map()) :: :ok | {:error, String.t()}
  def validate(metadata) when is_map(metadata) do
    cond do
      is_nil(metadata.guild_id) -> {:error, "guild_id is required"}
      !is_binary(metadata.guild_id) -> {:error, "guild_id must be a string"}
      true -> :ok
    end
  end

  def validate(_), do: {:error, "metadata must be a map"}

  # Private helpers

  defp base_metadata(guild_id, opts) when is_binary(guild_id) do
    %{
      guild_id: guild_id,
      client_version: opts[:client_version],
      server_version: Application.spec(:game_bot, :vsn) |> to_string()
    }
  end

  defp base_metadata(guild_id, opts) when is_integer(guild_id) do
    base_metadata(Integer.to_string(guild_id), opts)
  end

  defp maybe_add_correlation_id(metadata, nil) do
    Map.put(metadata, :correlation_id, generate_correlation_id())
  end
  defp maybe_add_correlation_id(metadata, correlation_id) do
    Map.put(metadata, :correlation_id, correlation_id)
  end

  defp maybe_add_causation_id(metadata, nil), do: metadata
  defp maybe_add_causation_id(metadata, causation_id) do
    Map.put(metadata, :causation_id, causation_id)
  end

  defp generate_correlation_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end

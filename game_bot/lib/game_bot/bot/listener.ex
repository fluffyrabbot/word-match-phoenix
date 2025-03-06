defmodule GameBot.Bot.Listener do
  @moduledoc """
  First line of defense for Discord message processing.
  Handles rate limiting, message validation, and spam detection before
  forwarding valid messages to the dispatcher.
  """

  use GenServer
  require Logger

  alias GameBot.Bot.Dispatcher
  alias Nostrum.Struct.{Message, Interaction}

  # Rate limiting configuration
  @rate_limit_window_seconds 60
  @max_messages_per_window 30
  @max_word_length 50
  @min_word_length 2

  # ETS table for rate limiting
  @rate_limit_table :rate_limit_store

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Create ETS table for rate limiting
    :ets.new(@rate_limit_table, [:named_table, :set, :public])
    {:ok, %{}}
  end

  @doc """
  Entry point for all Discord events. Handles both interactions and messages.
  """
  def handle_event({:INTERACTION_CREATE, interaction, _ws_state} = event) do
    # Interactions bypass most validation as they're already rate-limited by Discord
    with :ok <- validate_interaction(interaction) do
      Dispatcher.handle_event(event)
    else
      {:error, reason} ->
        Logger.warning("Invalid interaction",
          error: reason,
          interaction: interaction.id
        )
        respond_with_error(interaction, reason)
    end
  end

  def handle_event({:MESSAGE_CREATE, %Message{} = msg, _ws_state} = event) do
    with :ok <- validate_rate_limit(msg.author.id),
         :ok <- validate_message_format(msg.content),
         :ok <- validate_message_length(msg.content),
         :ok <- check_spam(msg) do
      Dispatcher.handle_event(event)
    else
      {:error, reason} ->
        Logger.warning("Message validation failed",
          error: reason,
          message_id: msg.id,
          author_id: msg.author.id
        )
        maybe_notify_user(msg, reason)
    end
  end

  def handle_event(_), do: :ok

  # Validation functions

  defp validate_rate_limit(user_id) do
    now = System.system_time(:second)
    window_start = now - @rate_limit_window_seconds

    case :ets.lookup(@rate_limit_table, user_id) do
      [] ->
        # First message in window
        :ets.insert(@rate_limit_table, {user_id, [now]})
        :ok

      [{^user_id, timestamps}] ->
        # Filter timestamps within window and check count
        recent = Enum.filter(timestamps, &(&1 >= window_start))
        if length(recent) >= @max_messages_per_window do
          {:error, :rate_limited}
        else
          :ets.insert(@rate_limit_table, {user_id, [now | recent]})
          :ok
        end
    end
  end

  defp validate_message_format(content) when is_binary(content) do
    cond do
      String.trim(content) == "" ->
        {:error, :empty_message}

      not String.valid?(content) ->
        {:error, :invalid_encoding}

      contains_control_chars?(content) ->
        {:error, :invalid_characters}

      true ->
        :ok
    end
  end

  defp validate_message_format(_), do: {:error, :invalid_format}

  defp validate_message_length(content) do
    len = String.length(content)
    cond do
      len > @max_word_length -> {:error, :message_too_long}
      len < @min_word_length -> {:error, :message_too_short}
      true -> :ok
    end
  end

  defp validate_interaction(%Interaction{} = interaction) do
    # Basic interaction validation
    # Most validation is handled by Discord's interaction system
    if interaction.type in [1, 2] do # 1 = Ping, 2 = Application Command
      :ok
    else
      {:error, :invalid_interaction_type}
    end
  end

  defp check_spam(%Message{} = msg) do
    # Basic spam detection
    cond do
      has_suspicious_mentions?(msg) ->
        {:error, :excessive_mentions}

      has_suspicious_content?(msg.content) ->
        {:error, :suspicious_content}

      true ->
        :ok
    end
  end

  # Helper functions

  defp contains_control_chars?(str) do
    String.match?(str, ~r/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/)
  end

  defp has_suspicious_mentions?(%Message{mentions: mentions}) do
    length(mentions) > 5
  end

  defp has_suspicious_content?(content) do
    # Check for common spam patterns
    String.match?(content, ~r/\b(https?:\/\/|www\.)\S+/i) or # Links
    String.match?(content, ~r/(.)\1{4,}/) or                 # Repeated characters
    String.match?(content, ~r/(.{3,})\1{2,}/)               # Repeated patterns
  end

  defp maybe_notify_user(%Message{channel_id: channel_id}, :rate_limited) do
    case Nostrum.Api.Message.create(channel_id, "You're sending messages too quickly. Please wait a moment.") do
      {:ok, _msg} -> :ok
      {:error, error} ->
        Logger.warning("Failed to send rate limit notification",
          error: error,
          channel_id: channel_id
        )
        :error
    end
  end
  defp maybe_notify_user(_, _), do: :ok

  defp respond_with_error(%Interaction{} = interaction, reason) do
    error_message = format_error_message(reason)
    Nostrum.Api.create_interaction_response(interaction, %{
      type: 4,
      data: %{
        content: error_message,
        flags: 64 # Ephemeral flag
      }
    })
  end

  defp format_error_message(:rate_limited), do: "You're sending commands too quickly. Please wait a moment."
  defp format_error_message(:message_too_long), do: "Your message is too long. Maximum length is #{@max_word_length} characters."
  defp format_error_message(:message_too_short), do: "Your message is too short. Minimum length is #{@min_word_length} characters."
  defp format_error_message(:invalid_characters), do: "Your message contains invalid characters."
  defp format_error_message(:excessive_mentions), do: "Too many mentions in your message."
  defp format_error_message(:suspicious_content), do: "Your message was flagged as potentially suspicious."
  defp format_error_message(_), do: "An error occurred processing your request."
end

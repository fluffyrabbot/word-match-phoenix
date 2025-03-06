defmodule GameBot.Bot.Listener do
  @moduledoc """
  First line of defense for Discord message processing.
  Handles rate limiting, message validation, and spam detection before
  forwarding valid messages to the dispatcher.

  ## Responsibilities
  - Rate limiting per user
  - Message content validation
  - Spam detection
  - Basic interaction validation
  - Error notifications to users

  ## Message Flow
  1. Receive Discord event
  2. Validate based on event type
     - Interactions: Basic type validation
     - Messages: Rate limiting, content validation, spam detection
  3. Forward valid events to Dispatcher
  4. Handle errors with appropriate user notifications
  """

  use GenServer
  require Logger

  alias GameBot.Bot.Dispatcher
  alias Nostrum.Struct.{Message, Interaction}
  alias GameBot.Bot.ErrorHandler

  @typedoc "Rate limiting configuration"
  @type rate_limit_config :: %{
    window_seconds: pos_integer(),
    max_messages: pos_integer()
  }

  @typedoc "Message validation error reasons"
  @type validation_error ::
    :rate_limited |
    :empty_message |
    :invalid_encoding |
    :invalid_characters |
    :invalid_format |
    :message_too_long |
    :message_too_short |
    :excessive_mentions |
    :suspicious_content

  # Rate limiting configuration
  @rate_limit_window_seconds Application.compile_env(:game_bot, :rate_limit_window_seconds, 60)
  @max_messages_per_window Application.compile_env(:game_bot, :max_messages_per_window, 30)
  @max_word_length Application.compile_env(:game_bot, :max_word_length, 50)
  @min_word_length Application.compile_env(:game_bot, :min_word_length, 2)
  @max_message_length 2000
  @min_message_length 1
  @max_mentions 5

  # Use the Registry to manage the rate limit table
  @rate_limit_table :rate_limit

  #
  # Public API
  #

  @doc """
  Starts the listener process.
  """
  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  #
  # GenServer Callbacks
  #

  @impl true
  def init(_opts) do
    # No need to create the table here; it will be created dynamically
    {:ok, %{}}
  end

  #
  # Event Handler Implementation
  #

  @doc """
  Entry point for all Discord events. Handles both interactions and messages.
  """
  def handle_event({:INTERACTION_CREATE, %Interaction{} = interaction, _ws_state}) do
    with :ok <- validate_interaction(interaction),
         :ok <- Dispatcher.handle_interaction(interaction) do
      Logger.info("Handling interaction: #{inspect(Map.take(interaction, [:id, :type]))}")
      :ok
    else
      {:error, reason} ->
        Logger.warning("Invalid interaction: #{inspect(reason)}")
        ErrorHandler.notify_interaction_error(interaction, reason)
        :error
      _ -> :error
    end
  end

  def handle_event({:MESSAGE_CREATE, %Message{} = message, _ws_state}) do
    with :ok <- validate_message(message),
         :ok <- Dispatcher.handle_message(message) do
      Logger.info("Processing message: #{inspect(Map.take(message, [:id, :author]))}")
      :ok
    else
      {:error, reason} ->
        Logger.warning("Message validation failed: #{inspect(reason)}")
        ErrorHandler.notify_user(message, reason)
        :error
      _ -> :error
    end
  end

  def handle_event(_), do: :ok

  #
  # Message Validation
  #

  @spec validate_message(Message.t()) :: :ok | {:error, validation_error()}
  defp validate_message(%Message{author: %{bot: true}}), do: {:error, :bot_message}
  defp validate_message(%Message{content: content} = message) do
    with :ok <- validate_message_format(content),
         :ok <- validate_message_length(content),
         :ok <- validate_rate_limit(message.author.id),
         :ok <- check_spam(message) do
      :ok
    end
  end

  @spec validate_message_format(String.t() | term()) :: :ok | {:error, validation_error()}
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

  @spec validate_message_length(String.t()) :: :ok | {:error, validation_error()}
  defp validate_message_length(content) do
    len = String.length(content)
    cond do
      len > @max_message_length -> {:error, :message_too_long}
      len < @min_message_length -> {:error, :message_too_short}
      true -> :ok
    end
  end

  #
  # Interaction Validation
  #

  @spec validate_interaction(Interaction.t()) :: :ok | {:error, :invalid_interaction_type}
  defp validate_interaction(%Interaction{type: type}) when type in [1, 2, 3], do: :ok
  defp validate_interaction(%Interaction{type: _type}), do: {:error, :invalid_type}

  #
  # Rate Limiting
  #

  @spec validate_rate_limit(String.t()) :: :ok | {:error, :rate_limited}
  defp validate_rate_limit(user_id) do
    now = System.system_time(:second)
    window_start = now - @rate_limit_window_seconds

    # Ensure rate limit table exists
    if :ets.whereis(@rate_limit_table) == :undefined do
      :ets.new(@rate_limit_table, [:set, :public, :named_table])
    end

    # Get current timestamps for user
    case :ets.lookup(@rate_limit_table, user_id) do
      [] ->
        # First message from this user
        :ets.insert(@rate_limit_table, {user_id, [now]})
        :ok
      [{^user_id, timestamps}] when is_list(timestamps) ->
        # Filter timestamps within window and check count
        recent_timestamps = Enum.filter(timestamps, &(&1 >= window_start))
        if length(recent_timestamps) >= @max_messages_per_window do
          {:error, :rate_limited}
        else
          # Add new timestamp and update
          :ets.insert(@rate_limit_table, {user_id, [now | recent_timestamps]})
          :ok
        end
      [{^user_id, timestamp}] when is_integer(timestamp) ->
        # Handle legacy single timestamp format
        if now - timestamp < @rate_limit_window_seconds do
          {:error, :rate_limited}
        else
          :ets.insert(@rate_limit_table, {user_id, [now]})
          :ok
        end
    end
  end

  #
  # Spam Detection
  #

  @spec check_spam(Message.t()) :: :ok | {:error, validation_error()}
  defp check_spam(%Message{} = msg) do
    cond do
      has_suspicious_mentions?(msg) ->
        {:error, :excessive_mentions}

      has_suspicious_content?(msg.content) ->
        {:error, :suspicious_content}

      true ->
        :ok
    end
  end

  @spec has_suspicious_mentions?(Message.t()) :: boolean()
  defp has_suspicious_mentions?(%Message{mentions: nil}), do: false
  defp has_suspicious_mentions?(%Message{mentions: mentions}) do
    length(mentions) > @max_mentions
  end

  @spec has_suspicious_content?(String.t()) :: boolean()
  defp has_suspicious_content?(content) do
    # Check for common spam patterns
    String.match?(content, ~r/\b(https?:\/\/|www\.)\S+/i) or # Links
    String.match?(content, ~r/(.)\1{4,}/) or                 # Repeated characters
    String.match?(content, ~r/(.{3,})\1{2,}/)               # Repeated patterns
  end

  # Helper function to check for control characters
  defp contains_control_chars?(content) do
    String.match?(content, ~r/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/)
  end
end

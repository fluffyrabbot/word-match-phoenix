defmodule GameBot.Bot.Dispatcher do
  @moduledoc """
  Routes incoming Discord events to appropriate handlers.
  """
  
  alias GameBot.Bot.CommandHandler

  @doc """
  Dispatches events received from Discord to the appropriate handlers.
  """
  def dispatch(event)

  def dispatch({:message_create, msg, _ws_state}) do
    # Route message create events to appropriate handler
    CommandHandler.handle_message(msg)
  end

  def dispatch({:ready, data, _ws_state}) do
    # Handle bot ready event
    IO.puts("Bot connected as #{data.user.username}##{data.user.discriminator}")
  end

  def dispatch(_event) do
    # Ignore other events
    :noop
  end
end 
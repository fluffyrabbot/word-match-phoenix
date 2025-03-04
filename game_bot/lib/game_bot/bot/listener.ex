defmodule GameBot.Bot.Listener do
  @moduledoc """
  Listens to Discord events and forwards them to the dispatcher.
  """
  
  use Nostrum.Consumer

  alias GameBot.Bot.Dispatcher

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  @doc """
  Callback function used by Nostrum to handle events.
  """
  def handle_event(event) do
    Dispatcher.dispatch(event)
    {:ok}
  end
end 
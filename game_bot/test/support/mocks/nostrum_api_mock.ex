defmodule GameBot.Test.Mocks.NostrumApiMock do
  use GenServer
  require Logger
  @behaviour Nostrum.Api

  @moduledoc """
  Mock implementation of Nostrum.Api functions for testing.
  """

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts ++ [name: __MODULE__])
  end

  def init(:ok) do
    {:ok, %{error: false}}
  end

  def simulate_error(value) do
    GenServer.cast(__MODULE__, {:simulate_error, value})
  end

  def should_error? do
    GenServer.call(__MODULE__, :should_error?)
  end

  # Message API
  def create_message(channel_id, message) do
    if GenServer.call(__MODULE__, :get_error) do
      Logger.warning("Simulating Nostrum API error for create_message")
      # Return a mocked ERROR response
      {:error, %{status_code: 500, message: "Simulated API error"}}
    else
      # Return a mock SUCCESS response
      {:ok, %{id: "mocked_message_id", channel_id: channel_id, content: message.content}}
    end
  end

  # Interaction API
  def create_interaction_response(interaction_id, interaction_token, response) do
    if GenServer.call(__MODULE__, :get_error) do
      Logger.warning("Simulating Nostrum API error for create_interaction_response")
      # Return a mocked ERROR response
      {:error, %{status_code: 500, message: "Simulated API error"}}
    else
      # Return a mock SUCCESS response
      {:ok, %{id: "mocked_interaction_id", interaction_id: interaction_id, token: interaction_token, data: response}}
    end
  end

  def get_channel_message(_channel_id, _message_id) do
    {:ok, %{id: "mock_message"}}
  end

  def get_guild_member(_guild_id, _user_id) do
    {:ok, %{user: %{id: "mock_user"}}}
  end

  # GenServer callbacks
  def handle_cast({:simulate_error, value}, state) do
    {:noreply, %{state | error: value}}
  end

  def handle_call(:should_error?, _from, state) do
    {:reply, state.error, state}
  end

  def get_error(pid) do
    GenServer.call(pid, :get_error)
  end

  def handle_call(:get_error, _from, state) do
    {:reply, state.error, state}
  end
end

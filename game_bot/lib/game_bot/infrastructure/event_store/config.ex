defmodule GameBot.Infrastructure.EventStore.Config do
  @moduledoc """
  Configuration for EventStore and event serialization.
  Provides the core event store functionality for the GameBot system.
  """

  use EventStore, otp_app: :game_bot

  def init(config) do
    # You can modify config here if needed, for example to read from environment variables
    {:ok, config}
  end

  # Configure custom serialization for events
  def serializer do
    GameBot.Infrastructure.EventStore.Serializer
  end

  def event_store_wait_for_schema? do
    # In test environment, we want to wait for schema to be ready
    Application.get_env(:game_bot, :env) == :test
  end

  # Removed custom child_spec to avoid double-starting the EventStore process.
  # The default implementation provided by `use EventStore` will be used.
  # def child_spec(_args) do
  #   Supervisor.child_spec(
  #     {EventStore, name: __MODULE__},
  #     id: __MODULE__,
  #     restart: :permanent
  #   )
  # end
end

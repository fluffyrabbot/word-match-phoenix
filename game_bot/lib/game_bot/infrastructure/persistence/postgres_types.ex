defmodule GameBot.PostgresTypes do
  @moduledoc """
  Defines custom PostgreSQL types used by the application.
  This module is needed for our configuration to ensure proper database type handling.
  """

  # Import the EventStore PostgresTypes directly for the correct type handling
  # This is a proxy module to simplify configuration

  # Delegate standard functions to EventStore.PostgresTypes
  defdelegate init(config), to: EventStore.PostgresTypes
  defdelegate matching(query_param, output_value), to: EventStore.PostgresTypes
  defdelegate encode(type, value, opts), to: EventStore.PostgresTypes
  defdelegate decode(type, value, opts), to: EventStore.PostgresTypes
  defdelegate types(), to: EventStore.PostgresTypes
  defdelegate format(), to: EventStore.PostgresTypes
end

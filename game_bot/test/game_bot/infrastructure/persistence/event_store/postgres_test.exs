defmodule GameBot.Infrastructure.Persistence.EventStore.PostgresTest do
  @moduledoc """
  DEPRECATED: This module is an alias for GameBot.Infrastructure.Persistence.EventStore.Adapter.PostgresTest.
  Use GameBot.Infrastructure.Persistence.EventStore.Adapter.PostgresTest directly instead.

  This module has been kept for backward compatibility but will be removed in a future release.
  """

  use ExUnit.Case, async: false

  # Add a deprecation warning
  @deprecated "Use GameBot.Infrastructure.Persistence.EventStore.Adapter.PostgresTest instead"

  # Simply run the tests from the adapter test module
  # No setup or tests defined here - all tests will be run by the adapter test module

  def __ex_unit__(_) do
    IO.warn("DEPRECATED: #{@deprecated}", Macro.Env.stacktrace(__ENV__))
    quote do
      # Import adapter tests
      import GameBot.Infrastructure.Persistence.EventStore.Adapter.PostgresTest
    end
  end
end

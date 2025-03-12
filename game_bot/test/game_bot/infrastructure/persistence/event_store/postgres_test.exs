defmodule GameBot.Infrastructure.Persistence.EventStore.PostgresTest do
  @moduledoc """
  DEPRECATED: This module is an alias for GameBot.Infrastructure.Persistence.EventStore.Adapter.PostgresTest.
  Use GameBot.Infrastructure.Persistence.EventStore.Adapter.PostgresTest directly instead.

  This module has been kept for backward compatibility but will be removed in a future release.
  """

  # Use a different test method that won't interfere with the actual test files
  use ExUnit.Case, async: false

  # Force output of the deprecation message for any test runs
  setup do
    IO.puts """
    ==================================================================================
    DEPRECATED MODULE: Use GameBot.Infrastructure.Persistence.EventStore.Adapter.PostgresTest

    This module is deprecated and only exists for backward compatibility.
    Please update any references to use the Adapter.PostgresTest module directly.
    ==================================================================================
    """

    :ok
  end

  # Add one simple test to indicate the deprecation
  test "module is deprecated" do
    # This simple test will pass but indicate the module should not be used
    assert true, "This module is DEPRECATED. Use Adapter.PostgresTest instead"
  end
end

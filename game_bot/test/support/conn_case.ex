defmodule GameBotWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use GameBotWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias GameBot.Infrastructure.Persistence.RepositoryManager

  using do
    quote do
      # The default endpoint for testing
      @endpoint GameBotWeb.Endpoint

      use GameBotWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import GameBotWeb.ConnCase
    end
  end

  setup tags do
    # Ensure repositories are started (double check since DataCase will also do this)
    RepositoryManager.ensure_all_started()

    # Set up sandbox using DatabaseHelper
    GameBot.Test.DatabaseHelper.setup_sandbox(tags)

    # Register cleanup callback
    on_exit(fn ->
      GameBot.Test.DatabaseHelper.cleanup_connections()
    end)

    # Initialize ETS tables that might be needed for tests
    ets_tables_to_ensure = [
      # Add your ETS table names here
      :game_bot_cache,
      :game_bot_session_cache,
      :game_bot_metrics
    ]

    # Ensure each table exists
    Enum.each(ets_tables_to_ensure, fn table_name ->
      unless :ets.info(table_name) != :undefined do
        :ets.new(table_name, [:named_table, :public, :set])
      end
    end)

    # Return connection
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end

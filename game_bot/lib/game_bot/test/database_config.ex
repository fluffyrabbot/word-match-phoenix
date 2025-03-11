defmodule GameBot.Test.DatabaseConfig do
  @moduledoc """
  Centralized configuration for test databases.

  This module provides a single source of truth for database names,
  connection parameters, and other configuration values used in testing.
  """

  # Standard database names
  @main_test_db "game_bot_test"
  @event_test_db "game_bot_eventstore_test"

  # Connection parameters
  @db_host "localhost"
  @db_user "postgres"
  @db_password "csstarahid"
  @db_port 5432

  # Timeouts (in milliseconds)
  @db_operation_timeout :timer.seconds(30)
  @db_connection_timeout :timer.seconds(30)
  @db_ownership_timeout :timer.minutes(1)

  # Pool configuration for async tests
  @async_pool_size System.schedulers_online() * 2
  @async_max_overflow @async_pool_size
  @async_queue_target 50
  @async_queue_interval 1000

  # Pool configuration for sync tests
  @sync_pool_size 5
  @sync_max_overflow 2
  @sync_queue_target 50
  @sync_queue_interval 1000

  @doc """
  Returns the standard name for the main test database.
  """
  def main_test_db, do: @main_test_db

  @doc """
  Returns the standard name for the event store test database.
  """
  def event_test_db, do: @event_test_db

  @doc """
  Returns the base configuration for database connections.
  """
  def base_config(opts \\ []) do
    async = Keyword.get(opts, :async, false)
    [
      hostname: @db_host,
      username: @db_user,
      password: @db_password,
      port: @db_port,
      pool_size: if(async, do: @async_pool_size, else: @sync_pool_size),
      pool_overflow: if(async, do: @async_max_overflow, else: @sync_max_overflow),
      queue_target: if(async, do: @async_queue_target, else: @sync_queue_target),
      queue_interval: if(async, do: @async_queue_interval, else: @sync_queue_interval),
      timeout: @db_operation_timeout,
      connect_timeout: @db_connection_timeout,
      ownership_timeout: @db_ownership_timeout
    ]
  end

  @doc """
  Returns the configuration for the main test database.
  """
  def main_db_config(opts \\ []) do
    Keyword.merge(base_config(opts), [
      database: @main_test_db,
      pool: Ecto.Adapters.SQL.Sandbox,
      ownership_timeout: @db_ownership_timeout
    ])
  end

  @doc """
  Returns the configuration for the event store test database.
  """
  def event_db_config(opts \\ []) do
    Keyword.merge(base_config(opts), [
      database: @event_test_db,
      pool: Ecto.Adapters.SQL.Sandbox,
      ownership_timeout: @db_ownership_timeout
    ])
  end

  @doc """
  Returns the configuration for a temporary admin connection to PostgreSQL.
  Used for database creation and cleanup operations.
  """
  def admin_config do
    Keyword.merge(base_config(), [
      database: "postgres",
      pool_size: 1,
      pool: DBConnection.ConnectionPool
    ])
  end

  @doc """
  Returns all timeouts as a keyword list.
  """
  def timeouts do
    [
      operation_timeout: @db_operation_timeout,
      connection_timeout: @db_connection_timeout,
      ownership_timeout: @db_ownership_timeout
    ]
  end

  @doc """
  Returns pool configuration for async tests.
  """
  def async_pool_config do
    [
      pool_size: @async_pool_size,
      max_overflow: @async_max_overflow,
      queue_target: @async_queue_target,
      queue_interval: @async_queue_interval
    ]
  end

  @doc """
  Returns pool configuration for sync tests.
  """
  def sync_pool_config do
    [
      pool_size: @sync_pool_size,
      max_overflow: @sync_max_overflow,
      queue_target: @sync_queue_target,
      queue_interval: @sync_queue_interval
    ]
  end

  @doc """
  Returns the maximum number of concurrent async tests that can be run.
  This is based on the pool size and max overflow settings.
  """
  def max_concurrent_tests do
    @async_pool_size + @async_max_overflow
  end
end

defmodule GameBot.Test.Config do
  @moduledoc """
  Centralized configuration for test environment.

  This module provides configuration values for the test environment
  with direct values to avoid circular dependencies while still supporting
  environment variable overrides.

  ## Usage

  ```elixir
  alias GameBot.Test.Config

  # Get database connection parameters
  conn_params = Config.postgres_test_connection_params()

  # Get timeout settings
  timeout = Config.timeout()
  ```
  """

  require Logger

  @doc """
  Returns a list of repositories that need to be started for tests.
  """
  def repositories do
    [
      GameBot.Infrastructure.Persistence.Repo,
      GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
    ]
  end

  @doc """
  Maximum number of retries for database operations.
  Can be overridden via the GAMEBOT_TEST_MAX_RETRIES environment variable.
  """
  def max_retries do
    parse_int_env("GAMEBOT_TEST_MAX_RETRIES", 3)
  end

  @doc """
  Default timeout for database operations in milliseconds.
  Can be overridden via the GAMEBOT_TEST_TIMEOUT environment variable.
  """
  def timeout do
    parse_int_env("GAMEBOT_TEST_TIMEOUT", 120000)
  end

  @doc """
  Connection ownership timeout in milliseconds.
  Can be overridden via the GAMEBOT_TEST_OWNERSHIP_TIMEOUT environment variable.
  """
  def ownership_timeout do
    parse_int_env("GAMEBOT_TEST_OWNERSHIP_TIMEOUT", 120000)
  end

  @doc """
  Database connection timeout in milliseconds.
  Can be overridden via the GAMEBOT_TEST_CONNECTION_TIMEOUT environment variable.
  """
  def connection_timeout do
    parse_int_env("GAMEBOT_TEST_CONNECTION_TIMEOUT", 120000)
  end

  @doc """
  Database startup retry interval in milliseconds.
  Can be overridden via the GAMEBOT_TEST_RETRY_INTERVAL environment variable.
  """
  def retry_interval do
    parse_int_env("GAMEBOT_TEST_RETRY_INTERVAL", 500)
  end

  @doc """
  Database username for test connections.
  Can be overridden via the POSTGRES_USER environment variable.
  """
  def db_username do
    System.get_env("POSTGRES_USER", "postgres")
  end

  @doc """
  Database password for test connections.
  Can be overridden via the POSTGRES_PASSWORD environment variable.
  """
  def db_password do
    System.get_env("POSTGRES_PASSWORD", "csstarahid")
  end

  @doc """
  Database hostname for test connections.
  Can be overridden via the POSTGRES_HOST environment variable.
  """
  def db_hostname do
    System.get_env("POSTGRES_HOST", "localhost")
  end

  @doc """
  Database port for test connections.
  Can be overridden via the POSTGRES_PORT environment variable.
  """
  def db_port do
    parse_int_env("POSTGRES_PORT", 5432)
  end

  @doc """
  Connection parameters for the PostgreSQL system database.
  """
  def postgres_system_connection_params do
    %{
      hostname: db_hostname(),
      username: db_username(),
      password: db_password(),
      database: "postgres", # System database
      port: db_port(),
      pool_size: 1,
      connect_timeout: connection_timeout()
    }
  end

  @doc """
  Connection parameters for the test database.
  """
  def postgres_test_connection_params do
    %{
      hostname: db_hostname(),
      username: db_username(),
      password: db_password(),
      database: "game_bot_test",
      port: db_port(),
      pool_size: 10,
      connect_timeout: connection_timeout()
    }
  end

  @doc """
  Sets the PGPASSWORD environment variable for command-line use.
  This allows shell scripts to connect without password prompts.
  Returns the previous value of PGPASSWORD.
  """
  def set_pg_password do
    prev = System.get_env("PGPASSWORD")
    System.put_env("PGPASSWORD", db_password())
    prev
  end

  @doc """
  Restores the PGPASSWORD environment variable to a previous value.
  """
  def restore_pg_password(prev_value) do
    if prev_value do
      System.put_env("PGPASSWORD", prev_value)
    else
      System.delete_env("PGPASSWORD")
    end
  end

  @doc """
  Returns the PostgreSQL command-line options as a string.
  This is useful for shell scripts that need to connect to the database.
  """
  def psql_options do
    "-U #{db_username()} -h #{db_hostname()} -p #{db_port()}"
  end

  @doc """
  Log current configuration for debugging purposes
  """
  def log_configuration do
    Logger.info("Test Configuration:")
    Logger.info("  Database:")
    Logger.info("    Host: #{db_hostname()}:#{db_port()}")
    Logger.info("    Username: #{db_username()}")
    Logger.info("    Password: #{String.duplicate("*", String.length(db_password()))}")
    Logger.info("  Timeouts:")
    Logger.info("    Timeout: #{timeout()}ms")
    Logger.info("    Connection Timeout: #{connection_timeout()}ms")
    Logger.info("    Ownership Timeout: #{ownership_timeout()}ms")
    Logger.info("  Retry Settings:")
    Logger.info("    Max Retries: #{max_retries()}")
    Logger.info("    Retry Interval: #{retry_interval()}ms")
  end

  # Private helpers

  defp parse_int_env(name, default) do
    case System.get_env(name) do
      nil -> default
      value ->
        case Integer.parse(value) do
          {int, _} -> int
          :error -> default
        end
    end
  end
end

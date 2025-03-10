defmodule GameBot.Test.DatabaseHelper do
  @moduledoc """
  Helper module for initializing and cleaning up the test database environment.

  This module handles the initialization of database connections, setting up
  sandboxes, and cleaning up connections between tests. It provides a centralized
  way to manage database resources for testing.
  """

  require Logger
  alias GameBot.Test.Config
  alias GameBot.Test.DatabaseConnectionManager

  # Repository initialization mutex to prevent race conditions
  @initialization_lock_key {__MODULE__, :initialization_lock}

  # Process registry for tracking test-related processes
  @process_registry_key {__MODULE__, :process_registry}

  @repos [
    GameBot.Infrastructure.Persistence.Repo,
    GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
  ]

  @doc """
  Initializes the test environment.

  This function:
  1. Acquires a lock to prevent concurrent initialization
  2. Starts the database repositories in the correct order
  3. Validates repository health after initialization
  4. Sets up the sandbox mode for repositories
  5. Initializes the test event store

  Returns:
  - `:ok` - If initialization is successful
  - `{:error, reason}` - If initialization fails
  """
  def initialize do
    Logger.info("Initializing test environment")

    # Use a process dictionary-based lock to prevent concurrent initialization
    case acquire_initialization_lock() do
      :ok ->
        try do
          do_initialize()
        after
          # Always release the lock, even if initialization fails
          release_initialization_lock()
        end

      {:error, :locked} ->
        Logger.info("Initialization already in progress, waiting...")
        # Wait for initialization to complete
        wait_for_initialization_to_complete()
    end
  end

  @doc """
  Cleans up the test environment.

  This function:
  1. Resets the test event store
  2. Stops the database repositories in the correct order
  3. Cleans up any monitored processes
  4. Terminates any remaining connections

  Returns:
  - `:ok` - If cleanup is successful
  - `{:error, reason}` - If cleanup fails
  """
  def cleanup do
    Logger.info("Cleaning up test environment")

    # First try the graceful approach
    DatabaseConnectionManager.graceful_shutdown()

    # Reset the event store
    reset_event_store()

    # Stop repositories in reverse order
    Enum.reverse(@repos)
    |> Enum.each(fn repo ->
      case stop_repo(repo) do
        :ok ->
          Logger.debug("#{inspect(repo)} stopped successfully")

        {:error, reason} ->
          Logger.warning("Failed to stop #{inspect(repo)}: #{inspect(reason)}")
      end
    end)

    # Clean up process registry
    cleanup_process_registry()

    Logger.info("Test environment cleanup completed")
    :ok
  end

  @doc """
  Alias for cleanup/0, provided for backward compatibility.
  """
  def cleanup_connections do
    cleanup()
  end

  @doc """
  Resets the sandbox for the test repositories.

  This is useful between tests to ensure test isolation.

  Returns:
  - `:ok` - If reset is successful
  - `{:error, reason}` - If reset fails
  """
  def reset_sandbox do
    Logger.debug("Resetting sandbox mode for repositories")

    Enum.each(@repos, fn repo ->
      if is_repo_running?(repo) do
        try do
          Ecto.Adapters.SQL.Sandbox.checkin(repo)
          Ecto.Adapters.SQL.Sandbox.checkout(repo, ownership_timeout: Config.ownership_timeout())
        rescue
          e ->
            Logger.warning("Error resetting sandbox for #{inspect(repo)}: #{inspect(e)}")
            # Try to recover by restarting the repository
            restart_repo(repo)
        end
      else
        Logger.warning("Repository #{inspect(repo)} is not running, attempting to start it")
        start_repo(repo)
      end
    end)

    :ok
  end

  @doc """
  Sets up the sandbox for tests based on the provided tags.

  This function is used in test case setup blocks to properly configure
  repositories for each test. It handles tags like :async and :timeout
  to appropriately configure the sandbox.

  Args:
    - tags: The test context tags map

  Returns:
    - `:ok` - If setup is successful
  """
  def setup_sandbox(tags) do
    Logger.debug("Setting up sandbox for test with tags: #{inspect(tags)}")

    # Get timeout from tags or use default
    timeout = Map.get(tags, :timeout, Config.ownership_timeout())

    # First ensure all repos are started
    ensure_all_repos_running()

    # Then configure sandbox for each repository
    Enum.each(@repos, fn repo ->
      if is_repo_running?(repo) do
        # Configure sandbox mode based on test tags
        configure_sandbox_mode(repo, tags, timeout)
      else
        Logger.error("Repository #{inspect(repo)} is not running, sandbox setup failed")
        {:error, :repository_not_running}
      end
    end)

    :ok
  end

  @doc """
  Validates that the test environment is properly initialized.

  This function checks that all required repositories are running and
  responsive, and that the test event store is properly initialized.

  Returns:
  - `:ok` - If validation is successful
  - `{:error, reason}` - If validation fails
  """
  def validate_environment do
    Logger.debug("Validating test environment")

    # Check that all repositories are running
    repo_status = Enum.reduce(@repos, :ok, fn repo, acc ->
      case acc do
        :ok ->
          if is_repo_running?(repo) do
            # Check that the repository is responsive
            case check_repo_responsiveness(repo) do
              :ok -> :ok
              error -> error
            end
          else
            {:error, {:repository_not_running, repo}}
          end

        error -> error
      end
    end)

    # Check that the test event store is initialized
    event_store_status = check_event_store_status()

    # Return the first error, if any
    case {repo_status, event_store_status} do
      {:ok, :ok} -> :ok
      {{:error, reason}, _} -> {:error, reason}
      {_, {:error, reason}} -> {:error, reason}
    end
  end

  @doc """
  Monitors a process to ensure it's tracked and cleaned up properly.

  This function adds the process to the process registry and sets up
  monitoring to handle process termination.

  Args:
    - pid: The process ID to monitor

  Returns:
    - `:ok` - If monitoring is successful
    - `{:error, reason}` - If monitoring fails
  """
  def monitor_process(pid) when is_pid(pid) do
    try do
      # Create a monitor for the process
      ref = Process.monitor(pid)

      # Add the process to our registry
      registry = Process.get(@process_registry_key, %{})
      updated_registry = Map.put(registry, ref, pid)
      Process.put(@process_registry_key, updated_registry)

      {:ok, ref}
    rescue
      e ->
        Logger.error("Failed to monitor process #{inspect(pid)}: #{inspect(e)}")
        {:error, :monitor_failed}
    end
  end

  @doc """
  Checks if a repository is running.

  Args:
    - repo: The repository module to check

  Returns:
    - `true` - If the repository is running
    - `false` - If the repository is not running
  """
  def is_repo_running?(repo) do
    case Process.whereis(repo) do
      pid when is_pid(pid) -> Process.alive?(pid)
      nil -> false
    end
  end

  @doc """
  Ensures all repositories are running, starting them if necessary.

  Returns:
    - `:ok` - If all repositories are running
    - `{:error, reason}` - If any repository fails to start
  """
  def ensure_all_repos_running do
    Enum.reduce(@repos, :ok, fn repo, acc ->
      case acc do
        :ok ->
          if not is_repo_running?(repo) do
            start_repo(repo)
          else
            :ok
          end
        error -> error
      end
    end)
  end

  @doc """
  Sets up database connections in shared mode for the current test process.

  This function should be called in each test module's setup block to ensure
  proper database connection ownership. It:

  1. Configures sandbox mode to :shared for all repositories
  2. Checks out connections with appropriate timeouts
  3. Returns a function to check connections back in after the test

  This is particularly important for tests that need to share database
  connections with GenServer processes.

  ## Returns

  - A cleanup function that should be called in on_exit
  """
  def setup_shared_mode_for_test(timeout \\ 15000) do
    repos = [
      GameBot.Infrastructure.Persistence.Repo,
      GameBot.Infrastructure.Persistence.EventStore.Adapter.Postgres
    ]

    # First ensure the repos are running
    ensure_all_repos_running()

    # Explicitly kill any existing owned connections for this process
    # This helps prevent ownership errors when previous tests didn't clean up properly
    Enum.each(repos, fn repo ->
      try do
        # Try to check in any existing connections for this process
        Ecto.Adapters.SQL.Sandbox.checkin(repo)
      rescue
        _ -> :ok
      catch
        _, _ -> :ok
      end
    end)

    # Wait a bit to allow connections to fully close
    Process.sleep(100)

    # Store the checkout results for diagnosis and cleanup
    checkout_results = Enum.map(repos, fn repo ->
      test_pid = self()
      Logger.debug("Checking out #{inspect(repo)} for test process #{inspect(test_pid)}")

      try do
        # Attempt to check out with the specified timeout
        checkout_result = Ecto.Adapters.SQL.Sandbox.checkout(repo,
          ownership_timeout: timeout,
          timeout: timeout
        )

        # Configure shared mode regardless of checkout result
        Ecto.Adapters.SQL.Sandbox.mode(repo, {:shared, test_pid})

        # Return checkout result for debugging
        {repo, :ok, checkout_result}
      rescue
        e ->
          Logger.error("Error checking out #{inspect(repo)}: #{inspect(e)}")
          {repo, :error, e}
      end
    end)

    # Check if any checkouts failed
    failed_checkouts = Enum.filter(checkout_results, fn {_, status, _} -> status == :error end)

    if length(failed_checkouts) > 0 do
      error_messages = Enum.map(failed_checkouts, fn {repo, _, error} ->
        "#{inspect(repo)}: #{inspect(error)}"
      end)

      Logger.error("Failed to check out repositories: #{Enum.join(error_messages, ", ")}")
      Logger.error("Attempting to recover by forcing shared mode")

      # Try to force shared mode even when checkout failed
      Enum.each(repos, fn repo ->
        try do
          Ecto.Adapters.SQL.Sandbox.mode(repo, {:shared, self()})
        rescue
          e -> Logger.error("Error setting shared mode for #{inspect(repo)}: #{inspect(e)}")
        end
      end)
    end

    # Return a cleanup function
    fn ->
      Enum.each(repos, fn repo ->
        try do
          # Try to check in any existing connections for this process
          Ecto.Adapters.SQL.Sandbox.checkin(repo)
          Logger.debug("Successfully checked in #{inspect(repo)}")
        rescue
          e ->
            Logger.warning("Error checking in repository #{inspect(repo)}: #{inspect(e)}")
            # If checkin fails, try to kill the connections directly
            try_kill_connections(repo)
        end
      end)
    end
  end

  # Helper to forcefully kill stuck connections for a repository
  defp try_kill_connections(repo) do
    Logger.debug("Attempting to kill connections for #{inspect(repo)}")

    # Find and kill connection processes associated with this repo
    for pid <- Process.list(),
        info = Process.info(pid, [:dictionary]) do
      if info && match?(%{:"$initial_call" => {Postgrex.Protocol, :init, 1}}, info[:dictionary]) do
        # Only kill connections for the specific repo
        conn_info = Process.info(pid, [:links])
        if conn_info && connected_to_repo?(conn_info[:links] || [], repo) do
          Logger.debug("Killing connection process: #{inspect(pid)}")
          Process.exit(pid, :kill)
        end
      end
    end

    # Small sleep to allow processes to terminate
    Process.sleep(50)
  end

  # Check if a connection is linked to the given repository
  defp connected_to_repo?(links, repo) do
    repo_pid = Process.whereis(repo)
    if repo_pid, do: Enum.member?(links, repo_pid), else: false
  end

  # Private Functions

  # Actual initialization implementation
  defp do_initialize do
    # Log configuration for debugging
    try do
      Logger.info("Test Configuration:")
      Logger.info("  Repositories: #{inspect(@repos)}")
      Logger.info("  Max retries: #{Config.max_retries()}")
      Logger.info("  Timeout: #{Config.timeout()}")
    rescue
      e -> Logger.error("Error logging configuration: #{inspect(e)}")
    end

    # Initialize process registry
    init_process_registry()

    # Start repositories
    start_result = start_repos()

    case start_result do
      :ok ->
        # Validate repository health
        validation_result = validate_repo_health()

        case validation_result do
          :ok ->
            # If validation passes, configure sandbox mode
            setup_sandbox(%{})
            # Initialize test event store
            initialize_test_event_store()
            Logger.info("Test environment initialized successfully")
            :ok

          error ->
            Logger.error("Repository health validation failed: #{inspect(error)}")
            error
        end

      error ->
        Logger.error("Failed to initialize test environment: #{inspect(error)}")
        error
    end
  end

  # Initialize process registry
  defp init_process_registry do
    Process.put(@process_registry_key, %{})
  end

  # Clean up process registry
  defp cleanup_process_registry do
    # Delete any registered processes
    Process.delete(@process_registry_key)
  end

  # Acquire an initialization lock
  defp acquire_initialization_lock do
    case Process.get(@initialization_lock_key) do
      nil ->
        # No lock exists, acquire it
        Process.put(@initialization_lock_key, self())
        :ok
      pid when pid == self() ->
        # We already hold the lock
        :ok
      _other_pid ->
        # Another process holds the lock
        {:error, :locked}
    end
  end

  # Release the initialization lock
  defp release_initialization_lock do
    Process.delete(@initialization_lock_key)
    :ok
  end

  # Wait for initialization to complete
  defp wait_for_initialization_to_complete do
    # Check if databases are initialized every 100ms
    if Enum.all?(@repos, &is_repo_running?/1) do
      Logger.debug("All repositories initialized by another process")
      :ok
    else
      # Wait and check again
      :timer.sleep(100)
      wait_for_initialization_to_complete()
    end
  end

  defp start_repos do
    Logger.debug("Starting repositories")

    # Start each repository
    Enum.reduce(@repos, :ok, fn repo, acc ->
      case acc do
        :ok ->
          case start_repo(repo) do
            :ok -> :ok
            error -> error
          end

        error -> error
      end
    end)
  end

  defp start_repo(repo) do
    Logger.debug("Starting repository: #{inspect(repo)}")

    # Try to start the repository with retries
    start_repo_with_retries(repo, Config.max_retries())
  end

  defp start_repo_with_retries(_repo, 0) do
    {:error, :max_retries_exceeded}
  end

  defp start_repo_with_retries(repo, retries) do
    try do
      # Check if repository is already started
      if is_repo_running?(repo) do
        Logger.debug("#{inspect(repo)} is already running")
        :ok
      else
        # Start the repository
        case repo.start_link([pool_size: 1]) do
          {:ok, pid} ->
            Logger.debug("#{inspect(repo)} started successfully")
            # Monitor the process
            monitor_process(pid)
            :ok

          {:error, {:already_started, pid}} ->
            Logger.debug("#{inspect(repo)} was already started")
            # Monitor the process
            monitor_process(pid)
            :ok

          {:error, error} ->
            Logger.warning("Error starting #{inspect(repo)}: #{inspect(error)}, retries left: #{retries - 1}")
            :timer.sleep(Config.retry_interval())
            start_repo_with_retries(repo, retries - 1)
        end
      end
    rescue
      e ->
        Logger.error("Exception starting #{inspect(repo)}: #{inspect(e)}, retries left: #{retries - 1}")
        :timer.sleep(Config.retry_interval())
        start_repo_with_retries(repo, retries - 1)
    end
  end

  defp restart_repo(repo) do
    Logger.debug("Restarting repository: #{inspect(repo)}")

    # First stop the repository
    stop_repo(repo)

    # Then start it again
    start_repo(repo)
  end

  defp stop_repo(repo) do
    Logger.debug("Stopping repository: #{inspect(repo)}")

    try do
      if is_repo_running?(repo) do
        # First, try graceful shutdown
        Process.whereis(repo)
        |> Process.exit(:normal)

        # Wait briefly to allow for graceful shutdown
        :timer.sleep(100)

        # If still alive, force shutdown
        if is_repo_running?(repo) do
          Process.whereis(repo)
          |> Process.exit(:kill)
        end

        :ok
      else
        Logger.debug("#{inspect(repo)} is not running")
        :ok
      end
    rescue
      e ->
        Logger.error("Error stopping #{inspect(repo)}: #{inspect(e)}")
        {:error, e}
    end
  end

  defp configure_sandbox_mode(repo, tags, timeout) do
    try do
      # Check if we should use shared mode based on async flag
      if Map.get(tags, :async, false) do
        # For async tests, use shared mode
        Ecto.Adapters.SQL.Sandbox.mode(repo, {:shared, self()})
      else
        # For non-async tests, use manual mode
        Ecto.Adapters.SQL.Sandbox.mode(repo, :manual)
      end

      # Checkout the repository with appropriate timeout
      Ecto.Adapters.SQL.Sandbox.checkout(repo, ownership_timeout: timeout)
    rescue
      e ->
        Logger.error("Error configuring sandbox for #{inspect(repo)}: #{inspect(e)}")
        {:error, e}
    end
  end

  defp validate_repo_health do
    Enum.reduce(@repos, :ok, fn repo, acc ->
      case acc do
        :ok ->
          check_repo_responsiveness(repo)
        error -> error
      end
    end)
  end

  defp check_repo_responsiveness(repo) do
    try do
      # Simple ping query to check if repository is responsive
      case repo.__adapter__() do
        Ecto.Adapters.Postgres ->
          case Ecto.Adapters.SQL.query(repo, "SELECT 1", []) do
            {:ok, _} -> :ok
            {:error, error} -> {:error, {:repository_not_responsive, repo, error}}
          end
        _ ->
          # For non-SQL repositories, we just check if the process is alive
          if is_repo_running?(repo) do
            :ok
          else
            {:error, {:repository_not_running, repo}}
          end
      end
    rescue
      e ->
        Logger.error("Error checking responsiveness for #{inspect(repo)}: #{inspect(e)}")
        {:error, {:repository_check_failed, repo, e}}
    end
  end

  defp initialize_test_event_store do
    try do
      # Check if TestEventStore is already running
      case Process.whereis(GameBot.TestEventStore) do
        nil ->
          Logger.debug("Starting TestEventStore")
          case GameBot.TestEventStore.start_link() do
            {:ok, pid} ->
              # Monitor the process
              monitor_process(pid)
              :ok
            error ->
              Logger.error("Failed to start TestEventStore: #{inspect(error)}")
              error
          end
        pid when is_pid(pid) ->
          Logger.debug("TestEventStore already running, resetting state")
          # Reset state if store already exists
          GameBot.TestEventStore.reset!()
          :ok
      end
    rescue
      e ->
        Logger.error("Error initializing TestEventStore: #{inspect(e)}")
        {:error, e}
    end
  end

  defp reset_event_store do
    try do
      # Try to reset the TestEventStore if it's running
      case Process.whereis(GameBot.TestEventStore) do
        nil ->
          Logger.warning("Event store is not running, cannot reset")
          :ok
        _pid ->
          GameBot.TestEventStore.reset!()
          :ok
      end
    rescue
      e ->
        Logger.error("Error resetting event store: #{inspect(e)}")
        {:error, e}
    end
  end

  defp check_event_store_status do
    try do
      case Process.whereis(GameBot.TestEventStore) do
        nil ->
          {:error, :event_store_not_running}
        pid ->
          if Process.alive?(pid) do
            # Try a simple operation to verify it's working
            case GameBot.TestEventStore.read_stream_forward("test-health-check") do
              {:ok, _, _, _} -> :ok
              error -> {:error, {:event_store_not_responsive, error}}
            end
          else
            {:error, :event_store_not_alive}
          end
      end
    rescue
      e ->
        Logger.error("Error checking event store status: #{inspect(e)}")
        {:error, {:event_store_check_failed, e}}
    end
  end
end

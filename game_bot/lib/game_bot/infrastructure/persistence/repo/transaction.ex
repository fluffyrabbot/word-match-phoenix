defmodule GameBot.Infrastructure.Persistence.Repo.Transaction do
  @moduledoc """
  Transaction management with guild_id context tracking.
  Provides transaction capabilities with proper logging and error handling.
  """

  alias GameBot.Infrastructure.Persistence.Repo.Postgres
  alias GameBot.Infrastructure.Persistence.Error
  require Logger

  # Maximum number of retries for transaction operations
  @max_retries 3
  # Delay between retries in milliseconds
  @retry_delay 1000

  @doc """
  Execute a database transaction with guild context tracking.

  ## Parameters
    - fun: The function to execute in the transaction
    - guild_id: The Discord guild ID for context tracking (optional)
    - opts: Additional transaction options

  ## Returns
    - {:ok, result} - Transaction succeeded
    - {:error, error} - Transaction failed
  """
  def execute(fun, guild_id \\ nil, opts \\ []) when is_function(fun, 0) do
    log_prefix = if guild_id, do: "[Guild: #{guild_id}]", else: "[No Guild]"

    Logger.debug("#{log_prefix} Starting transaction")

    # Attempt the transaction with retries for certain errors
    result = with_retry(fn ->
      Postgres.execute_transaction(fun, opts)
    end, @max_retries, log_prefix)

    case result do
      {:ok, value} ->
        Logger.debug("#{log_prefix} Transaction completed successfully")
        {:ok, value}
      {:error, %Error{} = error} ->
        # Add guild_id to error context if available
        error_with_guild = if guild_id do
          %Error{error | details: Map.put(error.details || %{}, :guild_id, guild_id)}
        else
          error
        end

        Logger.warning("#{log_prefix} Transaction failed: #{inspect(error_with_guild)}")
        {:error, error_with_guild}
    end
  end

  @doc """
  Execute a multi-step transaction with proper error handling.
  Takes a list of functions to execute in sequence, with each depending on the previous result.

  ## Parameters
    - steps: List of functions, each taking the result of the previous step
    - guild_id: The Discord guild ID for context tracking (optional)
    - opts: Additional transaction options

  ## Returns
    - {:ok, result} - All steps succeeded
    - {:error, error} - Transaction failed at a step
  """
  def execute_steps(steps, guild_id \\ nil, opts \\ []) when is_list(steps) do
    execute(
      fn ->
        Enum.reduce_while(steps, nil, fn
          step, nil when is_function(step, 0) ->
            case step.() do
              {:ok, result} -> {:cont, result}
              {:error, reason} -> {:halt, {:error, reason}}
              other -> {:cont, other}
            end
          step, acc when is_function(step, 1) ->
            case step.(acc) do
              {:ok, result} -> {:cont, result}
              {:error, reason} -> {:halt, {:error, reason}}
              other -> {:cont, other}
            end
        end)
      end,
      guild_id,
      opts
    )
  end

  @doc """
  Executes a function with retries on failure for recoverable database errors.

  ## Parameters
    - fun: The function to execute
    - retries: Number of retries remaining
    - log_prefix: Prefix for logging messages

  ## Returns
    - The result of the function if successful
    - The error result after all retries are exhausted
  """
  defp with_retry(fun, retries \\ @max_retries, log_prefix \\ "") do
    try do
      fun.()
    rescue
      e in [Postgrex.Error, DBConnection.ConnectionError] ->
        if retries > 0 and recoverable_error?(e) do
          Logger.warning("#{log_prefix} Database operation failed, retrying (#{retries} attempts left)... Error: #{inspect(e)}")
          Process.sleep(@retry_delay)
          with_retry(fun, retries - 1, log_prefix)
        else
          Logger.error("#{log_prefix} Database operation failed after retries or non-recoverable: #{inspect(e)}")
          {:error, %Error{type: :system, message: "Database error: #{inspect(e)}", context: __MODULE__}}
        end
      e ->
        Logger.error("#{log_prefix} Unexpected error in transaction: #{inspect(e)}")
        {:error, %Error{type: :system, message: "Unexpected error: #{inspect(e)}", context: __MODULE__}}
    catch
      :exit, reason ->
        if retries > 0 and recoverable_exit?(reason) do
          Logger.warning("#{log_prefix} Database operation exited, retrying (#{retries} attempts left)... Reason: #{inspect(reason)}")
          Process.sleep(@retry_delay)
          with_retry(fun, retries - 1, log_prefix)
        else
          Logger.error("#{log_prefix} Database operation exited after retries or non-recoverable: #{inspect(reason)}")
          {:error, %Error{type: :system, message: "Database operation terminated: #{inspect(reason)}", context: __MODULE__}}
        end
    end
  end

  # Determine if an error is likely recoverable
  defp recoverable_error?(%Postgrex.Error{} = error) do
    # Check for common recoverable Postgres errors
    case error.postgres do
      %{code: code} when code in ~w(57014 57P01 40001 40P01 08006 08001 08004) -> true
      %{code: code, message: message} ->
        # Connection timeout errors
        cond do
          code == "57014" and String.contains?(message, "timeout") -> true
          code == "57P01" and String.contains?(message, "terminate") -> true
          code == "57P01" and String.contains?(message, "terminating") -> true
          code == "57P01" and String.contains?(message, "connection") -> true
          true -> false
        end
      _ -> false
    end
  end

  defp recoverable_error?(%DBConnection.ConnectionError{} = error) do
    # Most connection errors are potentially recoverable
    String.contains?(error.message, "connection") or
    String.contains?(error.message, "timeout") or
    String.contains?(error.message, "disconnected")
  end

  defp recoverable_error?(_), do: false

  # Determine if an exit reason is likely recoverable
  defp recoverable_exit?({:timeout, _}), do: true
  defp recoverable_exit?({:shutdown, _}), do: true
  defp recoverable_exit?({:closed, _}), do: true
  defp recoverable_exit?(_), do: false
end

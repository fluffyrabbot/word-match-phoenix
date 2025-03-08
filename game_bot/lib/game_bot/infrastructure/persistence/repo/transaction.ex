defmodule GameBot.Infrastructure.Persistence.Repo.Transaction do
  @moduledoc """
  Transaction management with guild_id context tracking.
  Provides transaction capabilities with proper logging and error handling.
  """

  alias GameBot.Infrastructure.Persistence.Repo.Postgres
  alias GameBot.Infrastructure.Persistence.Error
  require Logger

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

    result = Postgres.execute_transaction(fun, opts)

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
end

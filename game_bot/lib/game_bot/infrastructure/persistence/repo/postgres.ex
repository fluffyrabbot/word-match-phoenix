defmodule GameBot.Infrastructure.Persistence.Repo.Postgres do
  @moduledoc """
  PostgreSQL implementation of the repository behavior.
  """

  use Ecto.Repo,
    otp_app: :game_bot,
    adapter: Ecto.Adapters.Postgres

  import Ecto.Query
  alias Ecto.Multi
  alias GameBot.Infrastructure.{Error, ErrorHelpers}

  @doc """
  Execute a function within a transaction.

  ## Options
    * `:timeout` - The time in milliseconds to wait for the transaction
    * `:isolation` - The isolation level for the transaction
  """
  def execute_transaction(fun, opts \\ []) do
    ErrorHelpers.with_retries(
      fn ->
        transaction(fn ->
          case fun.() do
            {:ok, result} -> result
            {:error, reason} -> Repo.rollback(reason)
            other -> other
          end
        end, opts)
      end,
      __MODULE__,
      max_retries: 3
    )
  end

  @doc """
  Execute multiple operations in a transaction using Ecto.Multi.
  """
  def execute_multi(multi, opts \\ []) do
    ErrorHelpers.with_retries(
      fn ->
        case transaction(fn -> Multi.to_list(multi) end, opts) do
          {:ok, results} -> {:ok, results}
          {:error, operation, reason, _changes} ->
            {:error, transaction_error(operation, reason)}
        end
      end,
      __MODULE__,
      max_retries: 3
    )
  end

  # Private Functions

  defp transaction_error(operation, reason) do
    Error.system_error(
      __MODULE__,
      "Transaction failed on operation: #{operation}",
      %{operation: operation, reason: reason}
    )
  end
end

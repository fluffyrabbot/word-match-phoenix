defmodule GameBot.Infrastructure.Persistence.Repo.Postgres do
  @moduledoc """
  PostgreSQL implementation of the repository behavior.
  """

  use Ecto.Repo,
    otp_app: :game_bot,
    adapter: Ecto.Adapters.Postgres

  import Ecto.Query
  alias Ecto.Multi
  alias GameBot.Infrastructure.Persistence.Error

  @doc """
  Execute a function within a transaction.

  ## Options
    * `:timeout` - The time in milliseconds to wait for the transaction
    * `:isolation` - The isolation level for the transaction
  """
  def execute_transaction(fun, opts \\ []) do
    try do
      transaction(fn ->
        case fun.() do
          {:ok, result} -> result
          {:error, reason} -> Repo.rollback(reason)
          other -> other
        end
      end, opts)
    rescue
      e in DBConnection.ConnectionError ->
        {:error, connection_error(e)}
      e ->
        {:error, system_error("Transaction failed", e)}
    end
  end

  @doc """
  Execute multiple operations in a transaction using Ecto.Multi.
  """
  def execute_multi(multi, opts \\ []) do
    try do
      case transaction(fn -> Multi.to_list(multi) end, opts) do
        {:ok, results} -> {:ok, results}
        {:error, operation, reason, _changes} ->
          {:error, transaction_error(operation, reason)}
      end
    rescue
      e in DBConnection.ConnectionError ->
        {:error, connection_error(e)}
      e ->
        {:error, system_error("Multi transaction failed", e)}
    end
  end

  # Private Functions

  defp transaction_error(operation, reason) do
    %Error{
      type: :transaction,
      context: __MODULE__,
      message: "Transaction failed on operation: #{operation}",
      details: %{operation: operation, reason: reason}
    }
  end

  defp connection_error(error) do
    %Error{
      type: :connection,
      context: __MODULE__,
      message: "Database connection error",
      details: %{error: error, retryable: true}
    }
  end

  defp system_error(message, error) do
    %Error{
      type: :system,
      context: __MODULE__,
      message: message,
      details: error
    }
  end
end

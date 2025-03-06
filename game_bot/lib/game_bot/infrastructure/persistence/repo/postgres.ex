defmodule GameBot.Infrastructure.Persistence.Repo.Postgres do
  @moduledoc """
  PostgreSQL implementation of the repository behavior.
  """

  use Ecto.Repo,
    otp_app: :game_bot,
    adapter: Ecto.Adapters.Postgres

  alias GameBot.Infrastructure.Persistence.Error

  # Define a different function name to avoid conflicts with the one from Ecto.Repo
  def execute_transaction(fun, opts \\ []) do
    try do
      case Ecto.Repo.transaction(__MODULE__, fun, opts) do
        {:ok, result} -> {:ok, result}
        {:error, reason} -> {:error, transaction_error(reason)}
      end
    rescue
      e in DBConnection.ConnectionError ->
        {:error, connection_error(e)}
      e ->
        {:error, system_error("Transaction failed", e)}
    end
  end

  # Private Functions

  defp transaction_error(reason) do
    %Error{
      type: :transaction,
      context: __MODULE__,
      message: "Transaction failed",
      details: %{reason: reason}
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

defmodule GameBot.Infrastructure.Persistence.Repo.Postgres do
  @moduledoc """
  PostgreSQL repository implementation with standardized error handling.
  """

  use Ecto.Repo,
    otp_app: :game_bot,
    adapter: Ecto.Adapters.Postgres

  @behaviour GameBot.Infrastructure.Persistence.Repo.Behaviour

  alias GameBot.Infrastructure.Persistence.Error

  @impl GameBot.Infrastructure.Persistence.Repo.Behaviour
  def transaction(fun) do
    try do
      super(fun)
    rescue
      e in Ecto.ConstraintError ->
        {:error, %Error{
          type: :validation,
          context: __MODULE__,
          message: "Constraint violation",
          details: %{
            constraint: e.constraint,
            type: e.type,
            message: e.message
          }
        }}
      e in Ecto.InvalidChangesetError ->
        {:error, %Error{
          type: :validation,
          context: __MODULE__,
          message: "Invalid changeset",
          details: e.changeset
        }}
      e ->
        {:error, %Error{
          type: :system,
          context: __MODULE__,
          message: "Transaction failed",
          details: e
        }}
    end
  end

  @impl GameBot.Infrastructure.Persistence.Repo.Behaviour
  def insert(struct, opts \\ []) do
    try do
      super(struct, opts)
    rescue
      e in Ecto.ConstraintError ->
        {:error, constraint_error(e)}
      e ->
        {:error, system_error("Insert failed", e)}
    end
  end

  @impl GameBot.Infrastructure.Persistence.Repo.Behaviour
  def update(struct, opts \\ []) do
    try do
      super(struct, opts)
    rescue
      e in Ecto.StaleEntryError ->
        {:error, %Error{
          type: :concurrency,
          context: __MODULE__,
          message: "Concurrent modification",
          details: %{struct: e.struct, attempted_value: e.attempted_value}
        }}
      e ->
        {:error, system_error("Update failed", e)}
    end
  end

  @impl GameBot.Infrastructure.Persistence.Repo.Behaviour
  def delete(struct, opts \\ []) do
    try do
      super(struct, opts)
    rescue
      e in Ecto.StaleEntryError ->
        {:error, %Error{
          type: :concurrency,
          context: __MODULE__,
          message: "Concurrent deletion",
          details: %{struct: e.struct}
        }}
      e ->
        {:error, system_error("Delete failed", e)}
    end
  end

  # Private Functions

  defp constraint_error(%{constraint: constraint, type: type} = e) do
    %Error{
      type: :validation,
      context: __MODULE__,
      message: "Constraint violation",
      details: %{
        constraint: constraint,
        type: type,
        message: e.message
      }
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

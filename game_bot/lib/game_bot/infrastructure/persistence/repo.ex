defmodule GameBot.Infrastructure.Persistence.Repo do
  @moduledoc """
  High-level repository interface providing standardized access to persistence.
  """

  alias GameBot.Infrastructure.Persistence.Error
  alias GameBot.Infrastructure.Persistence.Repo.Postgres

  @repo Application.compile_env(:game_bot, [__MODULE__, :implementation], Postgres)

  @doc """
  Executes the given function inside a transaction.
  """
  def transaction(fun) when is_function(fun, 0) do
    @repo.transaction(fun)
  end

  @doc """
  Inserts a struct into the repository.
  """
  def insert(struct, opts \\ []) do
    @repo.insert(struct, opts)
  end

  @doc """
  Updates a struct in the repository.
  """
  def update(struct, opts \\ []) do
    @repo.update(struct, opts)
  end

  @doc """
  Deletes a struct from the repository.
  """
  def delete(struct, opts \\ []) do
    @repo.delete(struct, opts)
  end

  @doc """
  Gets a single record by id.
  """
  def get(queryable, id, opts \\ []) do
    try do
      case @repo.get(queryable, id) do
        nil -> {:error, not_found_error(queryable, id)}
        record -> {:ok, record}
      end
    rescue
      e -> {:error, system_error("Failed to get record", e)}
    end
  end

  # Error Helpers

  defp not_found_error(queryable, id) do
    %Error{
      type: :not_found,
      context: __MODULE__,
      message: "Record not found",
      details: %{
        queryable: queryable,
        id: id
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

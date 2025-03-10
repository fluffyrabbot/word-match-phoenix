defmodule GameBot.Infrastructure.Repository do
  @moduledoc """
  Repository interface that delegates to configured implementation.

  This module provides a consistent API for database operations by delegating to
  the configured repository implementation, which can be the real PostgreSQL repository
  in production or a mock repository in tests.
  """

  @doc """
  Returns the configured repository implementation.
  """
  defp impl do
    # Check both configuration keys for backward compatibility
    Application.get_env(:game_bot, :repository_implementation) ||
      Application.get_env(:game_bot, :repo_implementation,
        GameBot.Infrastructure.Persistence.Repo.Postgres)
  end

  @doc """
  Executes a function within a transaction.

  ## Parameters
    * `fun` - The function to execute in the transaction
    * `opts` - Options for the transaction

  ## Returns
    * `{:ok, result}` - Transaction succeeded
    * `{:error, reason}` - Transaction failed
  """
  def transaction(fun, opts \\ []), do: impl().transaction(fun, opts)

  @doc """
  Inserts a struct into the database.

  ## Parameters
    * `struct` - The struct to insert
    * `opts` - Options for the insert operation

  ## Returns
    * `{:ok, struct}` - Insert succeeded
    * `{:error, changeset}` - Insert failed
  """
  def insert(struct, opts \\ []), do: impl().insert(struct, opts)

  @doc """
  Updates a struct in the database.

  ## Parameters
    * `struct` - The struct to update
    * `opts` - Options for the update operation

  ## Returns
    * `{:ok, struct}` - Update succeeded
    * `{:error, changeset}` - Update failed
  """
  def update(struct, opts \\ []), do: impl().update(struct, opts)

  @doc """
  Deletes a struct from the database.

  ## Parameters
    * `struct` - The struct to delete
    * `opts` - Options for the delete operation

  ## Returns
    * `{:ok, struct}` - Delete succeeded
    * `{:error, changeset}` - Delete failed
  """
  def delete(struct, opts \\ []), do: impl().delete(struct, opts)

  @doc """
  Rolls back a transaction.

  ## Parameters
    * `value` - The value to return after rolling back
  """
  def rollback(value), do: impl().rollback(value)

  @doc """
  Fetches a single result from the query.

  ## Parameters
    * `queryable` - The queryable to fetch from
    * `opts` - Options for the query

  ## Returns
    * `result` - The single result or nil
  """
  def one(queryable, opts \\ []), do: impl().one(queryable, opts)

  @doc """
  Fetches all results from the query.

  ## Parameters
    * `queryable` - The queryable to fetch from
    * `opts` - Options for the query

  ## Returns
    * `results` - A list of results
  """
  def all(queryable, opts \\ []), do: impl().all(queryable, opts)

  @doc """
  Fetches a record by its ID.

  ## Parameters
    * `queryable` - The queryable to fetch from
    * `id` - The ID to look up
    * `opts` - Options for the query

  ## Returns
    * `record` - The found record or nil
  """
  def get(queryable, id, opts \\ []), do: impl().get(queryable, id, opts)

  @doc """
  Deletes all records matching the query.

  ## Parameters
    * `queryable` - The queryable to delete from
    * `opts` - Options for the delete operation

  ## Returns
    * `{count, nil}` - Number of deleted records
  """
  def delete_all(queryable, opts \\ []), do: impl().delete_all(queryable, opts)
end

defmodule GameBot.Test.Mocks.MockRepo do
  @moduledoc """
  Mock repository implementation for testing.
  This module is used to mock database operations in tests.
  """

  @behaviour GameBot.Test.Mocks.RepoMock

  def transaction(fun, _opts \\ []) do
    try do
      result = fun.()
      {:ok, result}
    rescue
      e -> {:error, e}
    end
  end

  def insert(struct_or_changeset, _opts \\ []) do
    {:ok, struct_or_changeset}
  end

  def update(struct_or_changeset, _opts \\ []) do
    {:ok, struct_or_changeset}
  end

  def delete(struct_or_changeset, _opts \\ []) do
    {:ok, struct_or_changeset}
  end

  def one(_queryable, _opts \\ []) do
    nil
  end

  def all(_queryable, _opts \\ []) do
    []
  end

  def get(_queryable, _id, _opts \\ []) do
    nil
  end

  def get!(_queryable, _id, _opts \\ []) do
    raise Ecto.NoResultsError, queryable: "mock query"
  end

  def get_by(_queryable, _clauses, _opts \\ []) do
    nil
  end

  def get_by!(_queryable, _clauses, _opts \\ []) do
    raise Ecto.NoResultsError, queryable: "mock query"
  end

  def delete_all(_queryable, _opts \\ []) do
    {0, nil}
  end

  def update_all(_queryable, _updates, _opts \\ []) do
    {0, nil}
  end

  def insert_all(_schema_or_source, _entries, _opts \\ []) do
    {0, nil}
  end

  def exists?(_queryable, _opts \\ []) do
    false
  end

  def preload(struct_or_structs, _preloads, _opts \\ []) do
    struct_or_structs
  end

  def rollback(value) do
    throw({:ecto_rollback, value})
  end
end

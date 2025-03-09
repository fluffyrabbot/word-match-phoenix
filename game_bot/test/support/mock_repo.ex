defmodule GameBot.Infrastructure.Persistence.Repo.MockRepo do
  @moduledoc """
  Mock repository implementation for testing.

  This module implements the Repository.Behaviour interface and is used as a drop-in
  replacement for the real repository in tests. It provides default implementations
  for all repository functions that can be overridden by Mox expectations.
  """

  @behaviour GameBot.Infrastructure.Persistence.Repo.Behaviour

  # Default implementation for transaction
  @impl true
  def transaction(fun, _opts \\ []) do
    try do
      result = fun.()
      {:ok, result}
    rescue
      e -> {:error, e}
    catch
      :throw, {:ecto_rollback, value} -> {:error, value}
    end
  end

  # Default implementation for insert
  @impl true
  def insert(struct, _opts \\ []) do
    # For structs with auto-incrementing IDs, assign a fake ID
    struct = if Map.has_key?(struct, :id) && is_nil(Map.get(struct, :id)) do
      Map.put(struct, :id, System.unique_integer([:positive]))
    else
      struct
    end

    {:ok, struct}
  end

  # Default implementation for update
  @impl true
  def update(struct, _opts \\ []) do
    {:ok, struct}
  end

  # Default implementation for delete
  @impl true
  def delete(struct, _opts \\ []) do
    {:ok, struct}
  end

  # Default implementation for rollback
  @impl true
  def rollback(value) do
    throw({:ecto_rollback, value})
  end

  # Additional functions that are commonly used but not in the behaviour

  # Default implementation for one
  def one(_queryable, _opts \\ []) do
    nil
  end

  # Default implementation for all
  def all(_queryable, _opts \\ []) do
    []
  end

  # Default implementation for get
  def get(_queryable, _id, _opts \\ []) do
    nil
  end

  # Default implementation for get_by
  def get_by(_queryable, _clauses, _opts \\ []) do
    nil
  end

  # Default implementation for delete_all
  def delete_all(_queryable, _opts \\ []) do
    {0, nil}
  end

  # Default implementation for update_all
  def update_all(_queryable, _updates, _opts \\ []) do
    {0, nil}
  end

  # Default implementation for insert_all
  def insert_all(_schema_or_source, _entries, _opts \\ []) do
    {0, nil}
  end

  # Default implementation for exists?
  def exists?(_queryable, _opts \\ []) do
    false
  end

  # Default implementation for preload
  def preload(struct_or_structs, _preloads, _opts \\ []) do
    struct_or_structs
  end
end

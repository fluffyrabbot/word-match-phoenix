defmodule GameBot.Test.Mocks.RepoMock do
  @moduledoc """
  Mock repository behavior for testing.
  Defines all repository functions that can be mocked in tests.
  """

  @callback transaction(fun :: (() -> any()), opts :: Keyword.t()) ::
    {:ok, any()} | {:error, any()}

  @callback insert(struct_or_changeset :: struct() | Ecto.Changeset.t(), opts :: Keyword.t()) ::
    {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}

  @callback update(struct_or_changeset :: struct() | Ecto.Changeset.t(), opts :: Keyword.t()) ::
    {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}

  @callback delete(struct_or_changeset :: struct() | Ecto.Changeset.t(), opts :: Keyword.t()) ::
    {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}

  @callback one(queryable :: Ecto.Queryable.t(), opts :: Keyword.t()) ::
    Ecto.Schema.t() | nil | no_return()

  @callback all(queryable :: Ecto.Queryable.t(), opts :: Keyword.t()) ::
    [Ecto.Schema.t()] | no_return()

  @callback get(queryable :: Ecto.Queryable.t(), id :: term(), opts :: Keyword.t()) ::
    Ecto.Schema.t() | nil | no_return()

  @callback get!(queryable :: Ecto.Queryable.t(), id :: term(), opts :: Keyword.t()) ::
    Ecto.Schema.t() | no_return()

  @callback get_by(queryable :: Ecto.Queryable.t(), clauses :: Keyword.t() | map(), opts :: Keyword.t()) ::
    Ecto.Schema.t() | nil | no_return()

  @callback get_by!(queryable :: Ecto.Queryable.t(), clauses :: Keyword.t() | map(), opts :: Keyword.t()) ::
    Ecto.Schema.t() | no_return()

  @callback delete_all(queryable :: Ecto.Queryable.t(), opts :: Keyword.t()) ::
    {non_neg_integer(), nil | [term()]} | no_return()

  @callback update_all(queryable :: Ecto.Queryable.t(), updates :: Keyword.t(), opts :: Keyword.t()) ::
    {non_neg_integer(), nil | [term()]} | no_return()

  @callback insert_all(schema_or_source :: binary() | {binary(), module()} | module(),
                      entries :: [map() | Keyword.t()],
                      opts :: Keyword.t()) ::
    {non_neg_integer(), nil | [term()]} | no_return()

  @callback exists?(queryable :: Ecto.Queryable.t(), opts :: Keyword.t()) ::
    boolean() | no_return()

  @callback preload(struct_or_structs :: [Ecto.Schema.t()] | Ecto.Schema.t(),
                   preloads :: term(),
                   opts :: Keyword.t()) ::
    [Ecto.Schema.t()] | Ecto.Schema.t()

  @callback rollback(value :: any()) :: no_return()
end

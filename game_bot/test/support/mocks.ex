defmodule GameBot.Test.Mocks do
  @moduledoc """
  Mock implementations for external dependencies.
  """
end

defmodule GameBot.Mocks do
  @moduledoc """
  Defines mocks for testing, particularly for repository implementations.
  """

  # For backwards compatibility, we'll alias the mock to the test mocks namespace
  # This helps during the transition period
  defmodule GameBot.Test.Mocks.RepoMock do
    @moduledoc false

    # Just redefine the behavior here to avoid circular dependencies
    @callback transaction((() -> result), Keyword.t()) :: {:ok, result} | {:error, term()} when result: term()
    @callback transaction((() -> result)) :: {:ok, result} | {:error, term()} when result: term()
    @callback insert(struct(), Keyword.t()) :: {:ok, struct()} | {:error, term()}
    @callback insert(struct()) :: {:ok, struct()} | {:error, term()}
    @callback update(struct(), Keyword.t()) :: {:ok, struct()} | {:error, term()}
    @callback update(struct()) :: {:ok, struct()} | {:error, term()}
    @callback delete(struct(), Keyword.t()) :: {:ok, struct()} | {:error, term()}
    @callback delete(struct()) :: {:ok, struct()} | {:error, term()}
    @callback rollback(term()) :: no_return()
    @callback one(Ecto.Queryable.t(), Keyword.t()) :: term() | nil
    @callback all(Ecto.Queryable.t(), Keyword.t()) :: [term()]
    @callback get(Ecto.Queryable.t(), term(), Keyword.t()) :: term() | nil
    @callback delete_all(Ecto.Queryable.t(), Keyword.t()) :: {integer(), nil}
  end
end

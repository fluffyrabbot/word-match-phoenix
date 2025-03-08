defmodule GameBot.Infrastructure.Persistence.Repo.Behaviour do
  @moduledoc """
  Defines the core interface for repository implementations.
  """

  @callback transaction((() -> result), Keyword.t()) :: {:ok, result} | {:error, term()} when result: term()
  @callback transaction((() -> result)) :: {:ok, result} | {:error, term()} when result: term()

  @callback insert(struct(), Keyword.t()) :: {:ok, struct()} | {:error, term()}
  @callback insert(struct()) :: {:ok, struct()} | {:error, term()}

  @callback update(struct(), Keyword.t()) :: {:ok, struct()} | {:error, term()}
  @callback update(struct()) :: {:ok, struct()} | {:error, term()}

  @callback delete(struct(), Keyword.t()) :: {:ok, struct()} | {:error, term()}
  @callback delete(struct()) :: {:ok, struct()} | {:error, term()}

  @callback rollback(term()) :: no_return()
end

defmodule GameBot.Infrastructure.Persistence.Repo.Behaviour do
  @moduledoc """
  Defines the core interface for repository implementations.
  """

  @callback transaction((() -> result)) :: {:ok, result} | {:error, term()} when result: term()
  @callback insert(struct()) :: {:ok, struct()} | {:error, term()}
  @callback update(struct()) :: {:ok, struct()} | {:error, term()}
  @callback delete(struct()) :: {:ok, struct()} | {:error, term()}
end

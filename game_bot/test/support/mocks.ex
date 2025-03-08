defmodule GameBot.Test.Mocks do
  @moduledoc """
  Mock implementations for external dependencies.
  """
end

defmodule GameBot.Mocks do
  @moduledoc """
  Defines mocks for testing, particularly for repository implementations.
  """

  # Define mocks for tests
  Mox.defmock(GameBot.Infrastructure.Persistence.Repo.MockRepo,
    for: GameBot.Infrastructure.Persistence.Repo.Behaviour)
end

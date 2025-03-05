defmodule GameBot.Test.RepositoryCase do
  @moduledoc """
  Helper module for testing repository and event store implementations.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias GameBot.Infrastructure.Persistence.Error
      alias GameBot.Infrastructure.Persistence.{Repo, EventStore}
      alias GameBot.Infrastructure.Persistence.EventStore.{Adapter, Serializer}

      import GameBot.Test.RepositoryCase
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(GameBot.Infrastructure.Persistence.Repo.Postgres)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(GameBot.Infrastructure.Persistence.Repo.Postgres, {:shared, self()})
    end

    :ok
  end

  @doc """
  Creates a test event for serialization testing.
  """
  def build_test_event(type \\ "test_event") do
    %{
      event_type: type,
      event_version: 1,
      data: %{
        "test_field" => "test_value",
        "timestamp" => DateTime.utc_now()
      },
      stored_at: DateTime.utc_now()
    }
  end

  @doc """
  Creates a unique stream ID for testing.
  """
  def unique_stream_id, do: "test-#{:erlang.unique_integer([:positive])}"
end

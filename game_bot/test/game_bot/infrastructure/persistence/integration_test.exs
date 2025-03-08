defmodule GameBot.Infrastructure.Persistence.IntegrationTest do
  use GameBot.RepositoryCase, async: true

  alias GameBot.Infrastructure.Persistence.{Repo, EventStore}
  alias GameBot.Infrastructure.Persistence.EventStore.Adapter
  alias GameBot.Infrastructure.Persistence.Error
  alias GameBot.Infrastructure.Persistence.Repo.Postgres

  # Test schema for integration testing
  defmodule GameState do
    use Ecto.Schema
    import Ecto.Changeset

    schema "game_states" do
      field :game_id, :string
      field :state, :map
      field :version, :integer
      timestamps()
    end

    def changeset(struct \\ %__MODULE__{}, params) do
      struct
      |> cast(params, [:game_id, :state, :version])
      |> validate_required([:game_id, :state, :version])
      |> unique_constraint(:game_id)
      |> optimistic_lock(:version)
    end
  end

  setup do
    # Create test table
    Repo.query!("""
    CREATE TABLE IF NOT EXISTS game_states (
      id SERIAL PRIMARY KEY,
      game_id VARCHAR(255) NOT NULL UNIQUE,
      state JSONB NOT NULL,
      version INTEGER NOT NULL,
      inserted_at TIMESTAMP NOT NULL,
      updated_at TIMESTAMP NOT NULL
    )
    """)

    on_exit(fn ->
      Repo.query!("DROP TABLE IF EXISTS game_states")
    end)

    :ok
  end

  describe "event store and repository interaction" do
    test "successfully stores event and updates state" do
      game_id = unique_stream_id()
      event = build_test_event("game_started")

      result = Postgres.execute_transaction(fn ->
        # Append event to stream
        {:ok, _} = Adapter.append_to_stream(game_id, 0, [event])

        # Update game state
        {:ok, state} = Repo.insert(%GameState{
          game_id: game_id,
          state: %{status: "started"},
          version: 1
        })

        state
      end)

      assert {:ok, %GameState{}} = result
      assert {:ok, [stored_event]} = Adapter.read_stream_forward(game_id)
      assert stored_event.event_type == "game_started"
    end

    test "rolls back both event store and repository on error" do
      game_id = unique_stream_id()
      event = build_test_event("game_started")

      result = Postgres.execute_transaction(fn ->
        {:ok, _} = Adapter.append_to_stream(game_id, 0, [event])

        # Trigger validation error
        {:error, _} = Repo.insert(%GameState{
          game_id: game_id,
          state: nil, # Required field
          version: 1
        })
      end)

      assert {:error, %Error{type: :validation}} = result
      # Verify event was not stored
      assert {:error, %Error{type: :not_found}} =
        Adapter.read_stream_forward(game_id)
    end

    test "handles concurrent modifications across both stores" do
      game_id = unique_stream_id()
      event1 = build_test_event("game_started")
      event2 = build_test_event("game_updated")

      # First transaction
      {:ok, state} = Postgres.execute_transaction(fn ->
        {:ok, _} = Adapter.append_to_stream(game_id, 0, [event1])
        {:ok, state} = Repo.insert(%GameState{
          game_id: game_id,
          state: %{status: "started"},
          version: 1
        })
        state
      end)

      # Concurrent modification attempt
      result = Postgres.execute_transaction(fn ->
        # Try to append with wrong version
        {:ok, _} = Adapter.append_to_stream(game_id, 0, [event2])

        # Try to update with stale state
        Repo.update(Ecto.Changeset.change(state, state: %{status: "updated"}))
      end)

      assert {:error, %Error{type: :concurrency}} = result
    end
  end

  describe "subscription with state updates" do
    test "updates state based on received events" do
      game_id = unique_stream_id()

      # Subscribe to events
      {:ok, _subscription} = Adapter.subscribe_to_stream(game_id, self())

      # Insert initial state
      {:ok, _} = Repo.insert(%GameState{
        game_id: game_id,
        state: %{status: "initial"},
        version: 1
      })

      # Append event
      event = build_test_event("game_updated")
      {:ok, _} = Adapter.append_to_stream(game_id, 0, [event])

      # Verify we receive the event
      assert_receive {:events, [received_event]}
      assert received_event.event_type == "game_updated"

      # Verify state was updated
      {:ok, updated_state} = Repo.get_by(GameState, game_id: game_id)
      assert updated_state.version == 2
    end
  end
end

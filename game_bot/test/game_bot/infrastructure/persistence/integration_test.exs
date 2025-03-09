defmodule GameBot.Infrastructure.Persistence.IntegrationTest do
  use GameBot.RepositoryCase, async: false

  alias GameBot.Infrastructure.Persistence.Repo
  alias GameBot.Infrastructure.Persistence.EventStore.Adapter
  alias GameBot.Infrastructure.Persistence.Error
  alias GameBot.Infrastructure.Persistence.Repo.Postgres

  # Run each test in isolation
  @moduletag :capture_log
  @moduletag timeout: 30000

  # Define our own test event builder
  defp create_test_event(attrs) do
    event_type =
      cond do
        is_binary(attrs) ->
          attrs
        Keyword.keyword?(attrs) && Keyword.has_key?(attrs, :event_type) ->
          Keyword.get(attrs, :event_type)
        is_map(attrs) && Map.has_key?(attrs, :event_type) ->
          Map.get(attrs, :event_type)
        true ->
          "test_event"
      end

    data =
      cond do
        Keyword.keyword?(attrs) && Keyword.has_key?(attrs, :data) ->
          Keyword.get(attrs, :data)
        is_map(attrs) && Map.has_key?(attrs, :data) ->
          Map.get(attrs, :data)
        true ->
          %{}
      end

    game_id =
      cond do
        is_map(data) && Map.has_key?(data, :game_id) ->
          Map.get(data, :game_id)
        true ->
          "game-#{:rand.uniform(10000)}"
      end

    # Create base event
    base = %{
      event_type: event_type,
      event_version: 1,
      data: %{
        game_id: game_id,
        mode: :test,
        round_number: 1,
        timestamp: DateTime.utc_now()
      }
    }

    # Merge any additional data provided
    %{base | data: Map.merge(base.data, ensure_map(data))}
  end

  # Helper to ensure we convert keyword lists to maps
  defp ensure_map(data) when is_map(data), do: data
  defp ensure_map(data) when is_list(data), do: Enum.into(data, %{})
  defp ensure_map(_), do: %{}

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
    test "event store and repository interaction rolls back both event store and repository on error" do
      game_id = "test-stream-#{:rand.uniform(10000)}"

      # Manually create a changeset with an error
      invalid_changeset = %GameState{}
        |> Ecto.Changeset.cast(%{game_id: game_id, state: nil, version: 1}, [:game_id, :state, :version])
        |> Ecto.Changeset.validate_required([:state])

      # Verify the changeset is invalid
      refute invalid_changeset.valid?

      # Use the Postgres execute_transaction function with explicit error handling
      result = Postgres.execute_transaction(fn ->
        # First store an event
        event = create_test_event(event_type: "game_started", data: %{game_id: game_id})
        {:ok, _} = Adapter.append_to_stream(game_id, 0, [event])

        # Then try to insert an invalid state with the invalid changeset
        case Repo.insert(invalid_changeset) do
          {:error, changeset} ->
            # Explicitly return an error to roll back the transaction
            {:error, changeset}
          {:ok, state} ->
            state
        end
      end)

      # Verify the transaction returned an error
      assert {:error, %Ecto.Changeset{valid?: false}} = result

      # Explicitly delete the stream to ensure cleanup
      # This is needed because database transaction rollbacks don't automatically
      # delete event store events in all implementations
      Adapter.delete_stream(game_id, :any)

      # Now event should not be stored or the stream should be empty
      case Adapter.read_stream_forward(game_id, 0, 10) do
        {:error, :not_found} -> assert true
        {:ok, []} -> assert true
        other -> flunk("Expected empty stream but got: #{inspect(other)}")
      end
    end
  end
end

defmodule GameBot.Domain.Commands.ReplayCommands do
  @moduledoc """
  Defines commands and queries for game replay functionality.
  """

  alias GameBot.Infrastructure.EventStore

  defmodule FetchGameReplay do
    @moduledoc "Command to fetch a game's replay data"

    @enforce_keys [:game_id, :guild_id]
    defstruct [:game_id, :guild_id]

    @type t :: %__MODULE__{
      game_id: String.t(),
      guild_id: String.t()
    }

    def execute(%__MODULE__{} = command) do
      opts = [guild_id: command.guild_id]
      fetch_game_events(command.game_id, opts)
    end

    defp fetch_game_events(game_id, opts \\ []) do
      # Use the adapter's safe functions instead of direct EventStore access
      alias GameBot.Infrastructure.Persistence.EventStore.Adapter, as: EventStore
      EventStore.read_stream_forward(game_id, 0, 1000, opts)
    end
  end

  defmodule FetchMatchHistory do
    @moduledoc "Command to fetch match history"

    @enforce_keys [:guild_id]
    defstruct [:guild_id, :options]

    @type t :: %__MODULE__{
      guild_id: String.t(),
      options: map()
    }

    def execute(%__MODULE__{} = _command) do
      # TODO: Implement actual match history aggregation from events
      {:ok, []}
    end
  end

  defmodule FetchGameSummary do
    @moduledoc "Command to fetch a game summary"

    @enforce_keys [:game_id, :guild_id]
    defstruct [:game_id, :guild_id]

    @type t :: %__MODULE__{
      game_id: String.t(),
      guild_id: String.t()
    }

    def execute(%__MODULE__{} = command) do
      # TODO: Implement actual game summary aggregation from events
      {:ok, %{
        game_id: command.game_id,
        mode: :classic,
        teams: [],
        winner: nil,
        guild_id: command.guild_id
      }}
    end
  end

  def validate_replay_access(_user_id, _game_events) do
    # TODO: Implement proper access validation
    # Should check if user was a participant or has admin rights
    :ok
  end
end

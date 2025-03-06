defmodule GameBot.Domain.Events do
  @moduledoc """
  Contains event structs for the game domain.
  """

  defmodule GuessMatched do
    @derive Jason.Encoder
    defstruct [:game_id, :team_id, :player1_id, :player2_id,
               :word, :score, :timestamp, :guild_id]

    def event_type, do: "guess.matched"

    def validate(%__MODULE__{} = event) do
      cond do
        is_nil(event.game_id) -> {:error, "game_id is required"}
        is_nil(event.team_id) -> {:error, "team_id is required"}
        is_nil(event.guild_id) -> {:error, "guild_id is required"}
        true -> :ok
      end
    end
  end

  defmodule GuessNotMatched do
    @derive Jason.Encoder
    defstruct [:game_id, :team_id, :player1_id, :player2_id,
               :player1_word, :player2_word, :timestamp, :guild_id]

    def event_type, do: "guess.not_matched"

    def validate(%__MODULE__{} = event) do
      cond do
        is_nil(event.game_id) -> {:error, "game_id is required"}
        is_nil(event.team_id) -> {:error, "team_id is required"}
        is_nil(event.guild_id) -> {:error, "guild_id is required"}
        true -> :ok
      end
    end
  end

  defmodule PlayerJoined do
    @derive Jason.Encoder
    defstruct [:guild_id, :game_id, :player_id, :username, :joined_at]

    def event_type, do: "player.joined"

    def validate(%__MODULE__{} = event) do
      cond do
        is_nil(event.game_id) -> {:error, "game_id is required"}
        is_nil(event.player_id) -> {:error, "player_id is required"}
        is_nil(event.guild_id) -> {:error, "guild_id is required"}
        true -> :ok
      end
    end
  end
end

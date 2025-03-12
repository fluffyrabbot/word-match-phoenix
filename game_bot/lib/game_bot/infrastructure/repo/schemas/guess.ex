defmodule GameBot.Infrastructure.Repo.Schemas.Guess do
  @moduledoc """
  Ecto schema for the guesses table.

  Represents individual guess events in games, capturing the complete state of a guess
  for replay functionality. This includes both successful and unsuccessful guesses,
  as well as "give up" actions where one player submitted the "give up" command.

  This schema forms the foundation of the replay system, allowing accurate
  reconstruction of game timelines.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias GameBot.Infrastructure.Repo
  alias GameBot.Infrastructure.Repo.Schemas.{Game, GameRound, Team, User}
  alias GameBot.Domain.Events.GuessEvents.GuessProcessed

  @type t :: %__MODULE__{
    id: integer() | nil,
    game_id: integer(),
    round_id: integer(),
    guild_id: String.t(),
    team_id: integer(),
    player1_id: integer(),
    player2_id: integer(),
    player1_word: String.t(),
    player2_word: String.t(),
    successful: boolean(),
    match_score: integer() | nil,
    guess_number: integer(),
    round_guess_number: integer(),
    guess_duration: integer() | nil,
    player1_duration: integer() | nil,
    player2_duration: integer() | nil,
    event_id: Ecto.UUID.t() | nil,
    inserted_at: DateTime.t() | nil,
    updated_at: DateTime.t() | nil
  }

  schema "guesses" do
    belongs_to :game, Game
    belongs_to :round, GameRound
    field :guild_id, :string
    belongs_to :team, Team
    belongs_to :player1, User, foreign_key: :player1_id
    belongs_to :player2, User, foreign_key: :player2_id
    field :player1_word, :string
    field :player2_word, :string
    field :successful, :boolean, default: false
    field :match_score, :integer
    field :guess_number, :integer
    field :round_guess_number, :integer
    field :guess_duration, :integer
    field :player1_duration, :integer
    field :player2_duration, :integer
    field :event_id, Ecto.UUID

    timestamps()
  end

  @required_fields [
    :game_id, :round_id, :guild_id, :team_id,
    :player1_id, :player2_id, :player1_word, :player2_word,
    :successful, :guess_number, :round_guess_number
  ]
  @optional_fields [:match_score, :guess_duration, :player1_duration, :player2_duration, :event_id]

  @doc """
  Creates a changeset for a new guess or to update an existing guess.

  ## Parameters
    * `guess` - The existing guess or %Guess{} for a new guess
    * `attrs` - The attributes to set on the guess

  ## Returns
    * A changeset for the guess
  """
  def changeset(guess, attrs) do
    guess
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_match_score()
    |> foreign_key_constraint(:game_id)
    |> foreign_key_constraint(:round_id)
    |> foreign_key_constraint(:team_id)
    |> foreign_key_constraint(:player1_id)
    |> foreign_key_constraint(:player2_id)
  end

  @doc """
  Validates that match_score is only set when guess is successful.
  """
  def validate_match_score(changeset) do
    successful = get_field(changeset, :successful)
    match_score = get_field(changeset, :match_score)

    cond do
      successful == true && is_nil(match_score) ->
        add_error(changeset, :match_score, "must be present for successful guesses")
      successful == false && !is_nil(match_score) ->
        add_error(changeset, :match_score, "must be nil for unsuccessful guesses")
      true ->
        changeset
    end
  end

  @doc """
  Creates a guess record from a GuessProcessed event.

  ## Parameters
    * `event` - The GuessProcessed event
    * `round_id` - The ID of the game round
    * `guess_number` - The sequential number of this guess within the game
    * `round_guess_number` - The sequential number of this guess within the round

  ## Returns
    * `{:ok, guess}` - Successfully created guess
    * `{:error, changeset}` - Failed to create guess with errors
  """
  @spec create_from_event(GuessProcessed.t(), integer(), integer(), integer()) ::
    {:ok, t()} | {:error, Ecto.Changeset.t()}
  def create_from_event(event, round_id, guess_number, round_guess_number) do
    # Find the DB IDs for the referenced entities
    with {:ok, game_id} <- get_game_id_by_game_id(event.game_id),
         {:ok, team_id} <- get_team_id_by_team_id(event.team_id),
         {:ok, player1_id} <- get_user_id_by_discord_id(event.player1_info.id),
         {:ok, player2_id} <- get_user_id_by_discord_id(event.player2_info.id) do

      attrs = %{
        game_id: game_id,
        round_id: round_id,
        guild_id: event.guild_id,
        team_id: team_id,
        player1_id: player1_id,
        player2_id: player2_id,
        player1_word: event.player1_word,
        player2_word: event.player2_word,
        successful: event.guess_successful,
        match_score: event.match_score,
        guess_number: guess_number,
        round_guess_number: round_guess_number,
        guess_duration: event.guess_duration,
        player1_duration: event.player1_duration,
        player2_duration: event.player2_duration,
        event_id: get_event_id(event)
      }

      %__MODULE__{}
      |> changeset(attrs)
      |> Repo.insert()
    end
  end

  @doc """
  Gets guesses for a specific game, ordered by guess number.

  ## Parameters
    * `game_id` - The ID of the game

  ## Returns
    * List of guesses for the game
  """
  @spec get_guesses_for_game(String.t()) :: [t()]
  def get_guesses_for_game(game_id) when is_binary(game_id) do
    from(g in __MODULE__,
      join: game in Game, on: g.game_id == game.id,
      where: game.game_id == ^game_id,
      order_by: [asc: g.guess_number],
      preload: [:player1, :player2, :team]
    )
    |> Repo.all()
  end

  @doc """
  Gets guesses for a specific game and team, ordered by guess number.

  ## Parameters
    * `game_id` - The ID of the game
    * `team_id` - The ID of the team

  ## Returns
    * List of guesses for the game and team
  """
  @spec get_guesses_for_team(String.t(), String.t()) :: [t()]
  def get_guesses_for_team(game_id, team_id) when is_binary(game_id) and is_binary(team_id) do
    from(g in __MODULE__,
      join: game in Game, on: g.game_id == game.id,
      join: team in Team, on: g.team_id == team.id,
      where: game.game_id == ^game_id and team.id == ^team_id,
      order_by: [asc: g.guess_number],
      preload: [:player1, :player2]
    )
    |> Repo.all()
  end

  @doc """
  Checks if a guess contains a "give up" word from either player.

  ## Parameters
    * `guess` - The guess record to check

  ## Returns
    * `true` if either player submitted "give up"
    * `false` otherwise
  """
  @spec is_give_up?(t()) :: boolean()
  def is_give_up?(guess) do
    guess.player1_word == "give up" || guess.player2_word == "give up"
  end

  @doc """
  Gets the player who gave up in a "give up" guess.

  ## Parameters
    * `guess` - The guess record to check

  ## Returns
    * `{:player1, player1}` if player 1 gave up
    * `{:player2, player2}` if player 2 gave up
    * `:none` if neither player gave up
  """
  @spec get_give_up_player(t()) :: {:player1, User.t()} | {:player2, User.t()} | :none
  def get_give_up_player(guess) do
    cond do
      guess.player1_word == "give up" -> {:player1, guess.player1}
      guess.player2_word == "give up" -> {:player2, guess.player2}
      true -> :none
    end
  end

  # Private helper functions

  defp get_game_id_by_game_id(game_id) do
    case Repo.one(from g in Game, where: g.game_id == ^game_id, select: g.id) do
      nil -> {:error, :game_not_found}
      id -> {:ok, id}
    end
  end

  defp get_team_id_by_team_id(team_id) do
    case Repo.one(from t in Team, where: t.id == ^team_id, select: t.id) do
      nil -> {:error, :team_not_found}
      id -> {:ok, id}
    end
  end

  defp get_user_id_by_discord_id(discord_id) do
    case Repo.one(from u in User, where: u.discord_id == ^discord_id, select: u.id) do
      nil -> {:error, :user_not_found}
      id -> {:ok, id}
    end
  end

  defp get_event_id(%{metadata: metadata}) do
    case metadata do
      %{event_id: event_id} when is_binary(event_id) -> event_id
      _ -> nil
    end
  end
  defp get_event_id(_), do: nil
end

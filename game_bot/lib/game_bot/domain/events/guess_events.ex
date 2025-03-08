defmodule GameBot.Domain.Events do
  @moduledoc """
  Contains event structs for the game domain.
  """

  alias GameBot.Domain.Events.{Metadata, EventStructure}

  defmodule GuessProcessed do
    @moduledoc """
    Emitted when a guess attempt is processed.
    This event represents the complete lifecycle of a guess:
    1. Both players have submitted their words
    2. The guess has been validated
    3. The match has been checked
    4. The result has been recorded
    """

    use GameBot.Domain.Events.BaseEvent,
      event_type: "guess_processed",
      version: 1,
      fields: [
        field(:team_id, :string),
        field(:player1_info, :map),
        field(:player2_info, :map),
        field(:player1_word, :string),
        field(:player2_word, :string),
        field(:guess_successful, :boolean),
        field(:match_score, :integer),
        field(:guess_count, :integer),
        field(:round_guess_count, :integer),
        field(:total_guesses, :integer),
        field(:guess_duration, :integer)
      ]

    @impl true
    def required_fields do
      GameBot.Domain.Events.BaseEvent.base_required_fields() ++ [
        :team_id,
        :player1_info,
        :player2_info,
        :player1_word,
        :player2_word,
        :guess_successful,
        :guess_count,
        :round_guess_count,
        :total_guesses,
        :guess_duration
      ]
    end

    @impl true
    def validate_custom_fields(changeset) do
      super(changeset)
      |> validate_number(:guess_count, greater_than: 0)
      |> validate_number(:round_guess_count, greater_than: 0)
      |> validate_number(:total_guesses, greater_than: 0)
      |> validate_number(:guess_duration, greater_than_or_equal_to: 0)
      |> validate_match_score()
    end

    defp validate_match_score(changeset) do
      case {get_field(changeset, :guess_successful), get_field(changeset, :match_score)} do
        {true, nil} -> add_error(changeset, :match_score, "required when guess is successful")
        {false, score} when not is_nil(score) -> add_error(changeset, :match_score, "must be nil when guess is not successful")
        _ -> changeset
      end
    end

    # EventSerializer implementation

    defimpl GameBot.Domain.Events.EventSerializer do
      def to_map(event) do
        Map.from_struct(event)
        |> Map.update!(:timestamp, &DateTime.to_iso8601/1)
      end

      def from_map(data) do
        data
        |> Map.update!(:timestamp, &DateTime.from_iso8601!/1)
        |> struct(__MODULE__)
      end
    end

    # EventValidator implementation

    defimpl GameBot.Domain.Events.EventValidator do
      def validate(event) do
        with :ok <- validate_base_fields(event),
             :ok <- validate_metadata(event),
             :ok <- validate_guess_fields(event) do
          :ok
        end
      end

      def validate_fields(event, required_fields) do
        Enum.find_value(required_fields, :ok, fn field ->
          if Map.get(event, field) == nil do
            {:error, "#{field} is required"}
          else
            false
          end
        end)
      end

      defp validate_base_fields(event) do
        required = [:game_id, :guild_id, :mode, :round_number, :timestamp]
        validate_fields(event, required)
      end

      defp validate_metadata(event) do
        with %{metadata: metadata} <- event,
             true <- is_map(metadata) do
          if Map.has_key?(metadata, "guild_id") or Map.has_key?(metadata, :guild_id) or
             Map.has_key?(metadata, "source_id") or Map.has_key?(metadata, :source_id) do
            :ok
          else
            {:error, "guild_id or source_id is required in metadata"}
          end
        else
          _ -> {:error, "invalid metadata format"}
        end
      end

      defp validate_guess_fields(event) do
        cond do
          is_nil(event.team_id) -> {:error, "team_id is required"}
          is_nil(event.player1_info) -> {:error, "player1_info is required"}
          is_nil(event.player2_info) -> {:error, "player2_info is required"}
          is_nil(event.player1_word) -> {:error, "player1_word is required"}
          is_nil(event.player2_word) -> {:error, "player2_word is required"}
          is_nil(event.guess_successful) -> {:error, "guess_successful is required"}
          is_nil(event.guess_count) -> {:error, "guess_count is required"}
          is_nil(event.round_guess_count) -> {:error, "round_guess_count is required"}
          is_nil(event.total_guesses) -> {:error, "total_guesses is required"}
          is_nil(event.guess_duration) -> {:error, "guess_duration is required"}
          event.guess_count < 0 -> {:error, "guess_count must be non-negative"}
          event.round_guess_count < 0 -> {:error, "round_guess_count must be non-negative"}
          event.total_guesses < 0 -> {:error, "total_guesses must be non-negative"}
          event.guess_duration < 0 -> {:error, "guess_duration must be non-negative"}
          true -> :ok
        end
      end
    end
  end
end

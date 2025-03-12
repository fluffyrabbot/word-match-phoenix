defmodule GameBot.Domain.Events.EventValidatorImplementations do
  @moduledoc """
  Implementations of the EventValidator protocol for all event types.

  This module contains the specific validation logic for each event type in the system,
  ensuring they adhere to their respective schemas and business rules.
  """

  alias GameBot.Domain.Events.{EventValidator, EventValidatorHelpers}
  alias GameBot.Domain.Events.GameEvents.{
    GameStarted,
    GameCompleted,
    RoundStarted,
    GuessProcessed
  }

  defimpl EventValidator, for: GameStarted do
    alias GameBot.Domain.Events.EventValidatorHelpers, as: Helpers

    @doc """
    Validates a GameStarted event, ensuring it has:
    - All required base fields
    - Valid round_number (must be 1)
    - Valid teams structure
    - Valid start time
    """
    def validate(event) do
      event.__struct__.validate(event)
    end

    @doc """
    Validates the specific fields of a GameStarted event.
    """
    def validate_fields(event) do
      required_fields = [
        :round_number, :teams, :team_ids, :player_ids,
        :config, :started_at
      ]

      with :ok <- Helpers.validate_required(event, required_fields),
           :ok <- validate_round_number(event.round_number),
           :ok <- validate_teams(event),
           :ok <- validate_started_at(event.started_at) do
        :ok
      end
    end

    # Validation helpers

    defp validate_round_number(round_number) when is_integer(round_number) and round_number == 1, do: :ok
    defp validate_round_number(_), do: {:error, "round_number must be 1 for game start"}

    defp validate_teams(%{teams: teams, team_ids: team_ids, player_ids: player_ids}) do
      cond do
        not is_map(teams) ->
          {:error, "teams must be a map"}
        not is_list(team_ids) ->
          {:error, "team_ids must be a list"}
        not is_list(player_ids) ->
          {:error, "player_ids must be a list"}
        is_list(team_ids) and Enum.empty?(team_ids) ->
          {:error, "team_ids cannot be empty"}
        is_list(player_ids) and Enum.empty?(player_ids) ->
          {:error, "player_ids cannot be empty"}
        Enum.any?(teams, fn {_, players} -> is_list(players) and Enum.empty?(players) end) ->
          {:error, "Each team must have at least one player"}
        Enum.any?(team_ids, &(!Map.has_key?(teams, &1))) ->
          # Find the first team_id that's not in the teams map
          missing_team = Enum.find(team_ids, &(!Map.has_key?(teams, &1)))
          {:error, "team_ids contains unknown team: #{missing_team}"}
        !Enum.all?(Map.keys(teams), &(&1 in team_ids)) ->
          {:error, "invalid team_id in teams map"}
        !Enum.all?(List.flatten(Map.values(teams)), &(&1 in player_ids)) ->
          # Find the first player_id that's not in player_ids
          invalid_player = Enum.find(List.flatten(Map.values(teams)), &(!(&1 in player_ids)))
          {:error, "teams contains unknown player: #{invalid_player}"}
        true ->
          :ok
      end
    end

    defp validate_started_at(%DateTime{} = started_at) do
      case DateTime.compare(started_at, DateTime.utc_now()) do
        :gt -> {:error, "started_at cannot be in the future"}
        _ -> :ok
      end
    end
    defp validate_started_at(_), do: {:error, "started_at must be a DateTime"}
  end

  defimpl EventValidator, for: GuessProcessed do
    alias GameBot.Domain.Events.EventValidatorHelpers, as: Helpers

    @doc """
    Validates a GuessProcessed event, ensuring it has:
    - All required base fields
    - Valid round number
    - Valid team ID
    - Valid player info
    - Valid words
    - Valid guess metadata (successful, match score)
    - Valid guess counts (positive integers)
    - Valid guess duration (non-negative integer)
    - Valid player durations (non-negative integers)
    """
    def validate(event) do
      with :ok <- Helpers.validate_base_fields(event),
           :ok <- validate_fields(event) do
        :ok
      end
    end

    def validate_fields(event) do
      required_fields = [
        :round_number,
        :team_id,
        :player1_info,
        :player2_info,
        :player1_word,
        :player2_word,
        :guess_successful,
        :match_score,
        :guess_count,
        :round_guess_count,
        :total_guesses,
        :guess_duration,
        :player1_duration,
        :player2_duration
      ]

      # First check for required fields
      case Enum.filter(required_fields, &(not Map.has_key?(event, &1) or is_nil(Map.get(event, &1)))) do
        [] ->
          # All required fields are present, continue with validation
          with :ok <- Helpers.validate_positive_integer(event.round_number, "round_number"),
               :ok <- Helpers.validate_id(event.team_id, "team_id"),
               :ok <- validate_player_info(event.player1_info, "player1_info"),
               :ok <- validate_player_info(event.player2_info, "player2_info"),
               :ok <- validate_word(event.player1_word, "player1_word"),
               :ok <- validate_word(event.player2_word, "player2_word"),
               :ok <- validate_boolean(event.guess_successful, "guess_successful"),
               :ok <- validate_match_score(event),
               :ok <- validate_positive_counts(event),
               :ok <- validate_non_negative_duration(event.guess_duration),
               :ok <- validate_player_duration(event.player1_duration, "player1_duration"),
               :ok <- validate_player_duration(event.player2_duration, "player2_duration") do
            :ok
          end

        missing_fields ->
          # Report missing fields with consistent message format
          missing_field_names = Enum.map_join(missing_fields, ", ", &Atom.to_string/1)
          {:error, "Missing required fields: #{missing_field_names}"}
      end
    end

    # Validation helpers

    defp validate_player_info(info, field_name) do
      case info do
        {discord_id, username, nickname} when is_integer(discord_id) and is_binary(username) and (is_binary(nickname) or is_nil(nickname)) ->
          :ok
        _ ->
          {:error, "#{field_name} must be a tuple {discord_id, username, nickname} where discord_id is an integer, username is a string, and nickname is a string or nil"}
      end
    end

    defp validate_word(word, field_name) when is_binary(word) and word != "", do: :ok
    defp validate_word(_, field_name), do: {:error, "#{field_name} must be a non-empty string"}

    defp validate_boolean(value, field_name) when is_boolean(value), do: :ok
    defp validate_boolean(_, field_name), do: {:error, "#{field_name} must be a boolean"}

    defp validate_positive_counts(event) do
      counts = [
        event.guess_count,
        event.round_guess_count,
        event.total_guesses
      ]

      if Enum.all?(counts, &(is_integer(&1) and &1 > 0)) do
        :ok
      else
        {:error, "guess counts must be positive integers"}
      end
    end

    # Original function without field name (for backward compatibility)
    defp validate_non_negative_duration(duration) when is_integer(duration) and duration >= 0, do: :ok
    defp validate_non_negative_duration(_), do: {:error, "guess duration must be a non-negative integer"}

    # Separate function for player durations to ensure correct handling
    defp validate_player_duration(duration, field_name) when is_integer(duration) and duration >= 0, do: :ok
    defp validate_player_duration(_, field_name), do: {:error, "#{field_name} must be a non-negative integer"}

    # Validate match score based on guess_successful
    defp validate_match_score(event) do
      case {event.guess_successful, event.match_score} do
        {true, score} when is_integer(score) and score > 0 -> :ok
        {true, _} -> {:error, "match_score must be a positive integer when guess is successful"}
        {false, nil} -> :ok
        {false, _} -> {:error, "match_score must be nil when guess is not successful"}
      end
    end
  end

  defimpl EventValidator, for: RoundStarted do
    alias GameBot.Domain.Events.EventValidatorHelpers, as: Helpers

    @doc """
    Validates a RoundStarted event, ensuring it has:
    - All required base fields
    - Valid round_number
    - Valid words
    - Valid team states
    """
    def validate(event) do
      event.__struct__.validate(event)
    end

    @doc """
    Validates the specific fields of a RoundStarted event.
    """
    def validate_fields(event) do
      required_fields = [
        :round_number, :words, :team_states, :started_at
      ]

      with :ok <- Helpers.validate_required(event, required_fields),
           :ok <- Helpers.validate_positive_integer(event.round_number, "round_number"),
           :ok <- validate_words(event.words),
           :ok <- validate_team_states(event.team_states),
           :ok <- validate_started_at(event.started_at) do
        :ok
      end
    end

    # Validation helpers

    defp validate_words(words) when is_list(words) do
      if Enum.all?(words, &is_binary/1) do
        :ok
      else
        {:error, "words must be a list of strings"}
      end
    end
    defp validate_words(_), do: {:error, "words must be a list"}

    defp validate_team_states(team_states) when is_map(team_states) do
      Enum.reduce_while(team_states, :ok, fn {team_id, state}, :ok ->
        with :ok <- Helpers.validate_id(team_id, "team_id"),
             :ok <- validate_team_state(state) do
          {:cont, :ok}
        else
          error -> {:halt, error}
        end
      end)
    end
    defp validate_team_states(_), do: {:error, "team_states must be a map"}

    defp validate_team_state(state) when is_map(state) do
      required_keys = [:score, :matches, :available_words]

      missing_keys = Enum.filter(required_keys, fn key ->
        not Map.has_key?(state, key)
      end)

      if Enum.empty?(missing_keys) do
        with :ok <- Helpers.validate_non_negative_integer(state.score, "score"),
             :ok <- Helpers.validate_non_negative_integer(state.matches, "matches"),
             :ok <- validate_available_words(state.available_words) do
          :ok
        end
      else
        key_names = Enum.map_join(missing_keys, ", ", &Atom.to_string/1)
        {:error, "Missing required team state keys: #{key_names}"}
      end
    end
    defp validate_team_state(_), do: {:error, "team state must be a map"}

    defp validate_available_words(words) when is_integer(words) and words >= 0, do: :ok
    defp validate_available_words(_), do: {:error, "available_words must be a non-negative integer"}

    defp validate_started_at(%DateTime{} = started_at) do
      case DateTime.compare(started_at, DateTime.utc_now()) do
        :gt -> {:error, "started_at cannot be in the future"}
        _ -> :ok
      end
    end
    defp validate_started_at(_), do: {:error, "started_at must be a DateTime"}
  end

  # Implementation for GameCompleted if needed
  defimpl EventValidator, for: GameCompleted do
    alias GameBot.Domain.Events.EventValidatorHelpers, as: Helpers

    @doc """
    Validates a GameCompleted event, ensuring it has:
    - All required base fields
    - Valid game_id and other IDs
    - Valid winner information
    - Valid score data
    """
    def validate(event) do
      event.__struct__.validate(event)
    end

    @doc """
    Validates the specific fields of a GameCompleted event.
    """
    def validate_fields(event) do
      required_fields = [
        :game_id, :winning_team_id, :scores, :duration
      ]

      with :ok <- Helpers.validate_required(event, required_fields),
           :ok <- Helpers.validate_id(event.winning_team_id, "winning_team_id"),
           :ok <- validate_scores(event.scores),
           :ok <- Helpers.validate_positive_integer(event.duration, "duration") do
        :ok
      end
    end

    defp validate_scores(scores) when is_map(scores) do
      Enum.reduce_while(scores, :ok, fn {team_id, score}, :ok ->
        with :ok <- Helpers.validate_id(team_id, "team_id in scores"),
             :ok <- Helpers.validate_non_negative_integer(score, "score value") do
          {:cont, :ok}
        else
          error -> {:halt, error}
        end
      end)
    end
    defp validate_scores(_), do: {:error, "scores must be a map"}
  end
end

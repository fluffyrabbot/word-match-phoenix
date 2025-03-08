defmodule GameBot.Domain.Events.Validators do
  @moduledoc """
  Protocol implementations for EventValidator for various game events.
  """

  alias GameBot.Domain.Events.EventValidator
  alias GameBot.Domain.Events.GameEvents.{GuessProcessed, GameStarted}

  defimpl EventValidator, for: GuessProcessed do
    def validate(event) do
      with :ok <- validate_base_fields(event),
           :ok <- validate_fields(event) do
        :ok
      end
    end

    defp validate_base_fields(event) do
      required_fields = [:game_id, :guild_id, :mode, :timestamp, :metadata]

      case Enum.find(required_fields, &(is_nil(Map.get(event, &1)))) do
        nil -> :ok
        field -> {:error, "#{field} is required"}
      end
    end

    def validate_fields(event) do
      with :ok <- validate_required_fields(event),
           :ok <- validate_numeric_constraints(event) do
        :ok
      end
    end

    defp validate_required_fields(event) do
      required_fields = [
        :round_number,
        :team_id,
        :player1_info,
        :player2_info,
        :player1_word,
        :player2_word,
        :guess_successful
      ]

      case Enum.find(required_fields, &(is_nil(Map.get(event, &1)))) do
        nil -> :ok
        field -> {:error, "#{field} is required"}
      end
    end

    defp validate_numeric_constraints(event) do
      cond do
        not is_integer(event.round_number) or event.round_number <= 0 ->
          {:error, "round_number must be a positive integer"}

        not is_integer(event.guess_count) or event.guess_count <= 0 ->
          {:error, "guess_count must be a positive integer"}

        not is_integer(event.round_guess_count) or event.round_guess_count <= 0 ->
          {:error, "round_guess_count must be a positive integer"}

        not is_integer(event.total_guesses) or event.total_guesses <= 0 ->
          {:error, "total_guesses must be a positive integer"}

        not is_integer(event.guess_duration) or event.guess_duration < 0 ->
          {:error, "guess_duration must be a non-negative integer"}

        event.guess_successful and (not is_integer(event.match_score) or event.match_score <= 0) ->
          {:error, "match_score must be a positive integer when guess is successful"}

        not event.guess_successful and not is_nil(event.match_score) ->
          {:error, "match_score must be nil when guess is not successful"}

        true ->
          :ok
      end
    end
  end

  defimpl EventValidator, for: GameStarted do
    def validate(event) do
      with :ok <- validate_base_fields(event),
           :ok <- validate_fields(event) do
        :ok
      end
    end

    defp validate_base_fields(event) do
      required_fields = [:game_id, :guild_id, :mode, :timestamp, :metadata]

      case Enum.find(required_fields, &(is_nil(Map.get(event, &1)))) do
        nil -> :ok
        field -> {:error, "#{field} is required"}
      end
    end

    def validate_fields(event) do
      with :ok <- validate_required_fields(event),
           :ok <- validate_field_types(event) do
        :ok
      end
    end

    defp validate_required_fields(event) do
      required_fields = [
        :round_number,
        :teams,
        :team_ids,
        :player_ids,
        :roles,
        :config,
        :started_at
      ]

      case Enum.find(required_fields, &(is_nil(Map.get(event, &1)))) do
        nil -> :ok
        field -> {:error, "#{field} is required"}
      end
    end

    defp validate_field_types(event) do
      cond do
        event.round_number != 1 ->
          {:error, "round_number must be 1 for game start"}

        not is_map(event.teams) or Enum.empty?(event.teams) ->
          {:error, "teams must be a non-empty map"}

        not is_list(event.team_ids) or Enum.empty?(event.team_ids) ->
          {:error, "team_ids must be a non-empty list"}

        not is_list(event.player_ids) or Enum.empty?(event.player_ids) ->
          {:error, "player_ids must be a non-empty list"}

        not is_map(event.roles) ->
          {:error, "roles must be a map"}

        not is_map(event.config) ->
          {:error, "config must be a map"}

        not match?(%DateTime{}, event.started_at) ->
          {:error, "started_at must be a DateTime"}

        DateTime.compare(event.started_at, DateTime.utc_now()) == :gt ->
          {:error, "started_at cannot be in the future"}

        true ->
          :ok
      end
    end
  end
end

defmodule GameBot.Infrastructure.Persistence.EventStore.Serialization.Validator do
  @moduledoc """
  Event validation for the event store serialization process.

  This module provides validation functions that can be used during serialization
  and deserialization to ensure events conform to their schemas.
  """

  alias GameBot.Domain.Events.EventValidator
  alias GameBot.Infrastructure.Error

  @doc """
  Validates an event using the EventValidator protocol.

  ## Parameters
    * `event` - The event struct to validate

  ## Returns
    * `:ok` if the event is valid
    * `{:error, reason}` if validation fails
  """
  @spec validate(struct()) :: :ok | {:error, Error.t()}
  def validate(event) do
    try do
      case EventValidator.validate(event) do
        :ok -> :ok
        {:error, reason} when is_binary(reason) ->
          {:error, Error.validation_error(__MODULE__, reason, event)}
        {:error, reason} ->
          {:error, Error.validation_error(__MODULE__, "Validation failed", %{
            reason: reason,
            event: inspect(event)
          })}
      end
    rescue
      e in Protocol.UndefinedError ->
        # Protocol not implemented for this event type
        {:error, Error.validation_error(__MODULE__, "No validator defined for event type", %{
          event_type: event.__struct__,
          error: e
        })}
      e ->
        # Unexpected error during validation
        {:error, Error.validation_error(__MODULE__, "Validation error", %{
          error: e,
          stacktrace: __STACKTRACE__,
          event: inspect(event)
        })}
    end
  end

  @doc """
  Validates an event's structure from serialized data.
  Used during deserialization to validate the structure.

  ## Parameters
    * `data` - The serialized event data

  ## Returns
    * `:ok` if the data has valid structure
    * `{:error, reason}` if validation fails
  """
  @spec validate_structure(map()) :: :ok | {:error, Error.t()}
  def validate_structure(data) when is_map(data) do
    cond do
      not is_map(data) ->
        {:error, Error.validation_error(__MODULE__, "Event data must be a map", data)}
      not Map.has_key?(data, "type") and not Map.has_key?(data, "event_type") ->
        {:error, Error.validation_error(__MODULE__, "Event is missing type field", data)}
      not Map.has_key?(data, "version") and not Map.has_key?(data, "event_version") ->
        {:error, Error.validation_error(__MODULE__, "Event is missing version field", data)}
      not Map.has_key?(data, "data") ->
        {:error, Error.validation_error(__MODULE__, "Event is missing data field", data)}
      not is_map(Map.get(data, "data", nil)) ->
        {:error, Error.validation_error(__MODULE__, "Event data must be a map", data)}
      not is_map(Map.get(data, "metadata", %{})) ->
        {:error, Error.validation_error(__MODULE__, "Event metadata must be a map", data)}
      true ->
        :ok
    end
  end
  def validate_structure(data) do
    {:error, Error.validation_error(__MODULE__, "Event data must be a map", data)}
  end

  @doc """
  Validates event data against its schema before deserialization.
  This performs basic structural validation before creating the event struct.

  ## Parameters
    * `data` - The event data map
    * `event_type` - The type of event being validated

  ## Returns
    * `:ok` if the data is valid
    * `{:error, reason}` if validation fails
  """
  @spec validate_event_data(map(), String.t()) :: :ok | {:error, Error.t()}
  def validate_event_data(data, event_type) when is_map(data) and is_binary(event_type) do
    # Perform basic validation based on event type
    # This could be expanded with specific validation for each event type
    case event_type do
      "game_started" ->
        validate_game_started_data(data)

      "game_completed" ->
        validate_game_completed_data(data)

      "round_started" ->
        validate_round_started_data(data)

      "guess_processed" ->
        validate_guess_processed_data(data)

      _ ->
        # Default validation for unknown types
        :ok
    end
  end
  def validate_event_data(data, event_type) do
    {:error, Error.validation_error(__MODULE__, "Invalid event data or type", %{
      data: data,
      event_type: event_type
    })}
  end

  # Private validation functions for specific event types

  defp validate_game_started_data(data) do
    with :ok <- validate_required_fields(data, ["game_id", "guild_id", "mode"]),
         :ok <- validate_teams_data(data) do
      :ok
    end
  end

  defp validate_game_completed_data(data) do
    validate_required_fields(data, ["game_id", "guild_id", "winning_team_id"])
  end

  defp validate_round_started_data(data) do
    with :ok <- validate_required_fields(data, ["game_id", "guild_id", "round_number"]),
         :ok <- validate_words_list(data) do
      :ok
    end
  end

  defp validate_guess_processed_data(data) do
    validate_required_fields(data, [
      "game_id",
      "guild_id",
      "team_id",
      "player1_info",
      "player2_info",
      "player1_word",
      "player2_word"
    ])
  end

  defp validate_required_fields(data, fields) do
    missing = Enum.filter(fields, fn field -> not Map.has_key?(data, field) end)

    if Enum.empty?(missing) do
      :ok
    else
      {:error, Error.validation_error(__MODULE__, "Missing required fields", %{
        missing: missing,
        data: data
      })}
    end
  end

  defp validate_teams_data(%{"teams" => teams}) when is_map(teams) do
    if Enum.all?(teams, fn {_, players} -> is_list(players) end) do
      :ok
    else
      {:error, Error.validation_error(__MODULE__, "Teams must map to lists of player IDs", teams)}
    end
  end
  defp validate_teams_data(%{"teams" => teams}) do
    {:error, Error.validation_error(__MODULE__, "Teams must be a map", teams)}
  end
  defp validate_teams_data(_), do: :ok

  defp validate_words_list(%{"words" => words}) when is_list(words) do
    if Enum.all?(words, &is_binary/1) do
      :ok
    else
      {:error, Error.validation_error(__MODULE__, "Words must be a list of strings", words)}
    end
  end
  defp validate_words_list(%{"words" => words}) do
    {:error, Error.validation_error(__MODULE__, "Words must be a list", words)}
  end
  defp validate_words_list(_), do: :ok
end

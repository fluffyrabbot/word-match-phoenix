defmodule GameBot.Domain.Events.EventBuilderAdapter do
  @moduledoc """
  Adapter to integrate EventBuilder modules with the existing GameEvents behavior.

  This module provides a way to use the new EventBuilder pattern while ensuring
  compatibility with the existing GameEvents behavior and related functions.
  """

  defmacro __using__(_opts) do
    quote do
      # First use EventBuilder to get the standard functionality
      use GameBot.Domain.Events.EventBuilder

      # Then implement the GameEvents behavior
      @behaviour GameBot.Domain.Events.GameEvents

      # Implement required callbacks for GameEvents behavior
      @impl true
      def validate(event) do
        # Basic validation without pattern matching against __MODULE__
        # Each module can override this if needed
        :ok
      end

      @impl true
      def to_map(event) do
        # Convert to map without referencing __MODULE__
        map = Map.from_struct(event)

        # Process the values similar to the original implementation
        Enum.map(map, fn {k, v} ->
          value = case v do
            %DateTime{} -> DateTime.to_iso8601(v)
            v when is_atom(v) and not is_nil(v) -> Atom.to_string(v)
            _ -> v
          end
          {Atom.to_string(k), value}
        end)
        |> Map.new()
      end

      @impl true
      def from_map(data) do
        # Convert keys to atoms safely
        attrs = Enum.reduce(data, %{}, fn
          {key, val}, acc when is_binary(key) ->
            # Try to convert string keys to atoms
            key_atom = String.to_existing_atom(key)
            Map.put(acc, key_atom, val)
          {key, val}, acc when is_atom(key) ->
            # Keep atom keys as-is
            Map.put(acc, key, val)
        end)

        # Create struct without using pattern matching on __MODULE__
        struct!(__MODULE__, attrs)
      end
    end
  end
end

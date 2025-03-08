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

      # When using EventBuilderAdapter, we don't need to manually implement
      # these functions since they're already defined by EventBuilder.
      # The @impl true annotation ensures they satisfy the behavior's requirements.
      @impl true
      def validate(event), do: apply(__MODULE__, :validate, [event])

      @impl true
      def to_map(event), do: apply(__MODULE__, :to_map, [event])

      @impl true
      def from_map(data), do: apply(__MODULE__, :from_map, [data])
    end
  end
end

defmodule GameBot.Domain.Events.Builder do
  @moduledoc """
  Provides macros for creating event modules with consistent structure and behavior.
  """

  @doc """
  Creates a new event module with the specified fields and options.
  """
  defmacro defevent(name, fields, opts \\ []) do
    quote do
      defmodule unquote(name) do
        use GameBot.Domain.Events.BaseEvent,
          event_type: unquote(opts[:type] || to_string(name)),
          version: unquote(opts[:version] || 1),
          fields: unquote(fields)

        @doc """
        Creates a new event with the given attributes.
        """
        @spec new(Types.event_attrs()) :: t()
        def new(attrs) do
          %__MODULE__{}
          |> changeset(attrs)
          |> apply_changes()
        end

        @doc """
        Validates custom fields specific to this event type.
        Override this function to add custom validation.
        """
        def validate_custom_fields(changeset) do
          changeset
          |> validate_required(unquote(opts[:required_fields] || []))
          |> validate_custom_rules()
        end

        @doc """
        Validates custom rules specific to this event type.
        Override this function to add custom validation rules.
        """
        def validate_custom_rules(changeset), do: changeset

        @doc """
        Returns the event type.
        """
        def event_type, do: @event_type

        @doc """
        Returns the event version.
        """
        def event_version, do: @event_version
      end
    end
  end

  @doc """
  Creates a new event module with the specified fields and options.
  This is a convenience macro that provides default values for common options.
  """
  defmacro defevent_simple(name, fields, opts \\ []) do
    quote do
      defevent unquote(name), unquote(fields), Keyword.merge([
        type: to_string(name),
        version: 1,
        required_fields: []
      ], unquote(opts))
    end
  end
end

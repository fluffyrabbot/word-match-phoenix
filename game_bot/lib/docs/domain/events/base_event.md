# BaseEvent Module

## Overview

The `BaseEvent` module serves as the foundation for all events in the game system. It provides a consistent structure, shared functionality, and common validation rules through Elixir's macro system and Ecto's schema capabilities.

## Core Features

### Base Fields

All events inherit these base fields:
```elixir
@base_fields [
  :game_id,    # Unique identifier for the game
  :guild_id,   # Discord guild ID
  :mode,       # Game mode
  :round_number, # Current round number
  :timestamp,  # Event timestamp
  :metadata    # Additional context
]

@base_required_fields [
  :game_id,
  :guild_id,
  :mode,
  :round_number,
  :timestamp
]
```

### Schema Definition

```elixir
@primary_key {:id, :binary_id, autogenerate: true}
embedded_schema do
  field :game_id, :string
  field :guild_id, :string
  field :mode, Ecto.Enum, values: [:two_player, :knockout, :race]
  field :round_number, :integer
  field :timestamp, :utc_datetime_usec
  field :metadata, :map
end
```

### Type Specifications

```elixir
@type t :: %__MODULE__{
  id: Ecto.UUID.t(),
  game_id: String.t(),
  guild_id: String.t(),
  mode: :two_player | :knockout | :race,
  round_number: pos_integer(),
  timestamp: DateTime.t(),
  metadata: map()
}
```

## Usage

### Using BaseEvent in Event Modules

```elixir
defmodule MyEvent do
  use GameBot.Domain.Events.BaseEvent,
    event_type: "my_event",
    version: 1,
    fields: [
      field(:custom_field, :string),
      field(:another_field, :integer)
    ]
end
```

### Available Options

- `event_type` (required) - String identifier for the event
- `version` (optional, default: 1) - Event schema version
- `fields` (optional) - Additional fields specific to this event

## Callbacks and Extensions

### Required Callbacks

None - All necessary callbacks are provided by the BaseEvent implementation.

### Optional Callbacks

1. `required_fields/0`
   ```elixir
   @spec required_fields() :: [atom()]
   def required_fields do
     GameBot.Domain.Events.BaseEvent.base_required_fields() ++ [
       # Additional required fields
     ]
   end
   ```

2. `validate_custom_fields/1`
   ```elixir
   @spec validate_custom_fields(Ecto.Changeset.t()) :: Ecto.Changeset.t()
   def validate_custom_fields(changeset) do
     super(changeset)
     |> validate_custom_logic()
   end
   ```

## Validation

### Base Validation

1. Field presence
   ```elixir
   validate_required(changeset, required_fields())
   ```

2. Metadata structure
   ```elixir
   def validate_metadata(changeset) do
     validate_change(changeset, :metadata, fn :metadata, metadata ->
       case validate_metadata_structure(metadata) do
         :ok -> []
         {:error, reason} -> [metadata: reason]
       end
     end)
   end
   ```

### Custom Validation

Events can add custom validation by overriding `validate_custom_fields/1`:

```elixir
def validate_custom_fields(changeset) do
  super(changeset)
  |> validate_number(:count, greater_than: 0)
  |> validate_inclusion(:status, ["pending", "completed"])
end
```

## Serialization

### To Map

```elixir
def to_map(event) do
  Map.from_struct(event)
  |> Map.update!(:timestamp, &DateTime.to_iso8601/1)
end
```

### From Map

```elixir
def from_map(data) do
  data = if is_map(data) and map_size(data) > 0 and is_binary(hd(Map.keys(data))),
    do: data,
    else: Map.new(data, fn {k, v} -> {to_string(k), v} end)

  struct = struct(__MODULE__)

  Map.merge(struct, Map.new(data, fn
    {"timestamp", v} -> {:timestamp, DateTime.from_iso8601!(v)}
    {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
    {k, v} -> {k, v}
  end))
end
```

## Helper Functions

### Base Field Access

```elixir
def base_fields, do: @base_fields
def base_required_fields, do: @base_required_fields
def base_optional_fields, do: @base_optional_fields
```

### Event Creation

```elixir
def create_base(fields) do
  fields
  |> Map.put_new(:timestamp, DateTime.utc_now())
  |> Map.put_new(:metadata, %{})
end
```

### Metadata Handling

```elixir
def with_metadata(event, metadata) do
  Map.put(event, :metadata, metadata)
end

def event_id(%{metadata: %{source_id: id}}), do: id
def correlation_id(%{metadata: %{correlation_id: id}}), do: id
def causation_id(%{metadata: %{causation_id: id}}), do: id
```

## Best Practices

1. **Field Definition**
   - Use explicit types
   - Document constraints
   - Group related fields
   - Provide default values when appropriate

2. **Validation**
   - Always call `super` in custom validation
   - Use Ecto's built-in validators
   - Add custom validation for complex rules
   - Validate related fields together

3. **Metadata**
   - Include source_id or guild_id
   - Add correlation_id for event chains
   - Track causation_id for event relationships
   - Keep metadata focused and relevant

4. **Type Safety**
   - Use specific types over generic ones
   - Define comprehensive @type specs
   - Document field relationships
   - Leverage Ecto's type system

## Common Pitfalls

1. **Schema Definition**
   - DON'T define schema directly in event modules
   - DO use the `fields` option in `use BaseEvent`
   - DON'T duplicate base fields
   - DO extend base fields through `required_fields/0`

2. **Validation Chain**
   - DON'T skip calling `super` in overrides
   - DO maintain proper validation order
   - DON'T ignore validation results
   - DO handle all error cases

3. **Field Access**
   - DON'T access fields directly without validation
   - DO use BaseEvent helper functions
   - DON'T assume field presence
   - DO validate required fields

## Testing

Required test cases for events using BaseEvent:

1. **Base Field Validation**
   ```elixir
   test "validates base fields" do
     event = build(:my_event, game_id: nil)
     assert {:error, _} = EventValidator.validate(event)
   end
   ```

2. **Metadata Validation**
   ```elixir
   test "validates metadata structure" do
     event = build(:my_event, metadata: %{})
     assert {:error, _} = EventValidator.validate(event)
   end
   ```

3. **Custom Field Validation**
   ```elixir
   test "validates custom fields" do
     event = build(:my_event, custom_field: invalid_value)
     assert {:error, _} = EventValidator.validate(event)
   end
   ```

4. **Serialization**
   ```elixir
   test "serializes and deserializes" do
     event = build(:my_event)
     serialized = EventSerializer.to_map(event)
     deserialized = EventSerializer.from_map(serialized)
     assert event == deserialized
   end
   ``` 
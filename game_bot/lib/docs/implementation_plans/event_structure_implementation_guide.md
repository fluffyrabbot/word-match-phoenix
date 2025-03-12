# Event Structure Implementation Guide

## Overview

This document provides a step-by-step implementation guide for completing the Event Structure framework in the GameBot project. The Event Structure is the foundation of our event sourcing architecture and must be implemented correctly to ensure reliable state recovery, consistent event handling, and robust game mode implementations.

## Implementation Sequence

### Phase 1: Base Event Structure (4 days) - ✅ COMPLETED

#### 1.1 Enhanced Metadata Structure (Day 1-2) - ✅ COMPLETED

The enhanced metadata structure has been successfully implemented in `GameBot.Domain.Events.Metadata`. The module now provides:
- Comprehensive metadata type definition with required and optional fields
- Functions for creating metadata from different sources
- Support for causation and correlation tracking
- Optional guild_id for DM interactions
- Better validation for required fields

#### 1.2 BaseEvent Behavior (Day 2-3) - ✅ COMPLETED

The `BaseEvent` behavior has been implemented with:
- Standard callbacks for validation, serialization, and deserialization
- Generic type definition for events
- Default implementations that can be overridden
- Helper functions for event creation and metadata handling
- Support for inheritance through __using__ macro

#### 1.3 EventStructure Enhancements (Day 3-4) - ✅ COMPLETED

The `EventStructure` module has been enhanced with:
- Improved field validation
- Support for mode-specific validation
- Comprehensive serialization and deserialization
- Support for complex data types (DateTime, MapSet, structs)
- Recursive handling of nested structures

### Phase 2: Event Registry & Serialization (3 days) - ✅ COMPLETED

#### 2.1 Validation Framework (Day 1-2)

##### Implementation Steps
1. **Update EventStructure Validation**
   ```elixir
   # In lib/game_bot/domain/events/event_structure.ex
   
   # Add mode-specific validation
   def validate(event = %{mode: mode}) do
     with :ok <- validate_base_fields(event),
          :ok <- validate_metadata(event),
          :ok <- validate_mode_specific(event, mode) do
       :ok
     end
   end
   
   defp validate_mode_specific(event, :two_player) do
     case Code.ensure_loaded?(GameBot.Domain.GameModes.TwoPlayerMode) and
          function_exported?(GameBot.Domain.GameModes.TwoPlayerMode, :validate_event, 1) do
       true -> GameBot.Domain.GameModes.TwoPlayerMode.validate_event(event)
       false -> :ok
     end
   end
   
   defp validate_mode_specific(event, :knockout) do
     case Code.ensure_loaded?(GameBot.Domain.GameModes.KnockoutMode) and
          function_exported?(GameBot.Domain.GameModes.KnockoutMode, :validate_event, 1) do
       true -> GameBot.Domain.GameModes.KnockoutMode.validate_event(event)
       false -> :ok
     end
   end
   
   defp validate_mode_specific(event, :race) do
     case Code.ensure_loaded?(GameBot.Domain.GameModes.RaceMode) and
          function_exported?(GameBot.Domain.GameModes.RaceMode, :validate_event, 1) do
       true -> GameBot.Domain.GameModes.RaceMode.validate_event(event)
       false -> :ok
     end
   end
   
   defp validate_mode_specific(_, _), do: :ok
   ```

2. **Add Validation Helpers**
   ```elixir
   # Add to lib/game_bot/domain/events/event_structure.ex
   
   def validate_fields(event, required_fields) do
     Enum.find_value(required_fields, :ok, fn field ->
       if Map.get(event, field) == nil do
         {:error, "#{field} is required"}
       else
         false
       end
     end)
   end
   
   def validate_types(event, field_types) do
     Enum.find_value(field_types, :ok, fn {field, type_check} ->
       value = Map.get(event, field)
       if value != nil and not type_check.(value) do
         {:error, "#{field} has invalid type"}
       else
         false
       end
     end)
   end
   ```

#### 2.2 Update Existing Event Modules (Day 2-3)

##### Implementation Steps
1. **Update GameCreated Event**
   ```elixir
   # In lib/game_bot/domain/events/game_events.ex or separate file
   defmodule GameBot.Domain.Events.GameEvents.GameCreated do
     @moduledoc """
     Event generated when a new game is created.
     """
     use GameBot.Domain.Events.BaseEvent, type: "game_created", version: 1
     
     @required_fields [:game_id, :guild_id, :mode, :created_by, :created_at, :teams, :metadata, :timestamp]
     defstruct @required_fields
     
     @impl true
     def validate(event) do
       with :ok <- EventStructure.validate_fields(event, @required_fields),
            :ok <- validate_teams(event.teams),
            :ok <- super(event) do
         :ok
       end
     end
     
     defp validate_teams(teams) when is_list(teams), do: :ok
     defp validate_teams(_), do: {:error, "teams must be a list"}
     
     # Event-specific constructor
     def new(game_id, guild_id, mode, created_by, teams, metadata) do
       %__MODULE__{
         game_id: game_id,
         guild_id: guild_id,
         mode: mode,
         created_by: created_by,
         created_at: EventStructure.create_timestamp(),
         teams: teams,
         metadata: metadata,
         timestamp: EventStructure.create_timestamp()
       }
     end
     
     @impl true
     def deserialize(data) do
       struct(__MODULE__, Map.get(data, "data", %{}))
     end
   end
   ```

2. **Update GameStarted Event**
   ```elixir
   # In lib/game_bot/domain/events/game_events.ex or separate file
   defmodule GameBot.Domain.Events.GameEvents.GameStarted do
     @moduledoc """
     Event generated when a game session starts.
     """
     use GameBot.Domain.Events.BaseEvent, type: "game_started", version: 1
     
     @required_fields [:game_id, :guild_id, :mode, :round_number, :teams, 
                      :team_ids, :player_ids, :config, :metadata, :timestamp]
     defstruct @required_fields ++ [:started_at, :roles]
     
     @impl true
     def validate(event) do
       with :ok <- EventStructure.validate_fields(event, @required_fields),
            :ok <- validate_teams(event.teams),
            :ok <- validate_player_ids(event.player_ids),
            :ok <- super(event) do
         :ok
       end
     end
     
     defp validate_teams(teams) when is_list(teams), do: :ok
     defp validate_teams(_), do: {:error, "teams must be a list"}
     
     defp validate_player_ids(player_ids) when is_list(player_ids), do: :ok
     defp validate_player_ids(_), do: {:error, "player_ids must be a list"}
     
     # Event-specific constructor
     def new(game_id, guild_id, mode, round_number, teams, team_ids, player_ids, config, metadata) do
       %__MODULE__{
         game_id: game_id,
         guild_id: guild_id,
         mode: mode,
         round_number: round_number,
         teams: teams,
         team_ids: team_ids,
         player_ids: player_ids,
         config: config,
         metadata: metadata,
         timestamp: EventStructure.create_timestamp()
       }
     end
     
     @impl true
     def deserialize(data) do
       struct(__MODULE__, Map.get(data, "data", %{}))
     end
   end
   ```

### Phase 3: Mode-Specific Event Types (4 days)

#### 3.1 Common Game Events (Day 1)

##### Implementation Steps
1. **Create Common Game Events**
   ```elixir
   # In lib/game_bot/domain/events/game_events/round_events.ex
   defmodule GameBot.Domain.Events.GameEvents.RoundStarted do
     @moduledoc """
     Event generated when a new round begins.
     """
     use GameBot.Domain.Events.BaseEvent, type: "round_started", version: 1
     
     @required_fields [:game_id, :guild_id, :mode, :round_number, :team_states, 
                      :metadata, :timestamp]
     defstruct @required_fields ++ [:config, :timeouts]
     
     @impl true
     def validate(event) do
       with :ok <- EventStructure.validate_fields(event, @required_fields),
            :ok <- validate_team_states(event.team_states),
            :ok <- super(event) do
         :ok
       end
     end
     
     defp validate_team_states(team_states) when is_map(team_states), do: :ok
     defp validate_team_states(_), do: {:error, "team_states must be a map"}
     
     # Constructor
     def new(game_id, guild_id, mode, round_number, team_states, metadata, opts \\ []) do
       %__MODULE__{
         game_id: game_id,
         guild_id: guild_id,
         mode: mode,
         round_number: round_number,
         team_states: team_states,
         config: Keyword.get(opts, :config, %{}),
         timeouts: Keyword.get(opts, :timeouts, %{}),
         metadata: metadata,
         timestamp: EventStructure.create_timestamp()
       }
     end
   end
   ```

2. **Implement RoundCompleted Event**
   ```elixir
   # In lib/game_bot/domain/events/game_events/round_events.ex
   defmodule GameBot.Domain.Events.GameEvents.RoundCompleted do
     @moduledoc """
     Event generated when a round completes.
     """
     use GameBot.Domain.Events.BaseEvent, type: "round_completed", version: 1
     
     @required_fields [:game_id, :guild_id, :mode, :round_number, :scores, 
                      :metadata, :timestamp]
     defstruct @required_fields ++ [:round_winners, :stats]
     
     @impl true
     def validate(event) do
       with :ok <- EventStructure.validate_fields(event, @required_fields),
            :ok <- validate_scores(event.scores),
            :ok <- super(event) do
         :ok
       end
     end
     
     defp validate_scores(scores) when is_map(scores), do: :ok
     defp validate_scores(_), do: {:error, "scores must be a map"}
     
     # Constructor
     def new(game_id, guild_id, mode, round_number, scores, metadata, opts \\ []) do
       %__MODULE__{
         game_id: game_id,
         guild_id: guild_id,
         mode: mode,
         round_number: round_number,
         scores: scores,
         round_winners: Keyword.get(opts, :round_winners, []),
         stats: Keyword.get(opts, :stats, %{}),
         metadata: metadata,
         timestamp: EventStructure.create_timestamp()
       }
     end
   end
   ```

#### 3.2 Mode-Specific Events (Day 2-3)

##### Implementation Steps
1. **Create Two Player Mode Events**
   ```elixir
   # In lib/game_bot/domain/events/game_events/two_player_events.ex
   defmodule GameBot.Domain.Events.GameEvents.GuessProcessed do
     @moduledoc """
     Event generated when a word pair is processed in Two Player Mode.
     """
     use GameBot.Domain.Events.BaseEvent, type: "guess_processed", version: 1
     
     @required_fields [:game_id, :guild_id, :mode, :round_number, :team_id, 
                      :player1_info, :player2_info, :player1_word, :player2_word,
                      :match_score, :guess_successful, :metadata, :timestamp]
     defstruct @required_fields ++ [:guess_count]
     
     @impl true
     def validate(event) do
       with :ok <- EventStructure.validate_fields(event, @required_fields),
            :ok <- validate_player_info(event.player1_info),
            :ok <- validate_player_info(event.player2_info),
            :ok <- super(event) do
         :ok
       end
     end
     
     defp validate_player_info(%{player_id: _id}) when is_map(_id), do: :ok
     defp validate_player_info(_), do: {:error, "player_info must contain player_id"}
     
     # Constructor
     def new(game_id, guild_id, round_number, team_id, player1_info, player2_info, 
             player1_word, player2_word, match_score, guess_successful, metadata, opts \\ []) do
       %__MODULE__{
         game_id: game_id,
         guild_id: guild_id,
         mode: :two_player,
         round_number: round_number,
         team_id: team_id,
         player1_info: player1_info,
         player2_info: player2_info,
         player1_word: player1_word,
         player2_word: player2_word,
         match_score: match_score,
         guess_successful: guess_successful,
         guess_count: Keyword.get(opts, :guess_count, 1),
         metadata: metadata,
         timestamp: EventStructure.create_timestamp()
       }
     end
   end
   ```

2. **Create Knockout Mode Events**
   ```elixir
   # In lib/game_bot/domain/events/game_events/knockout_events.ex
   defmodule GameBot.Domain.Events.GameEvents.TeamEliminated do
     @moduledoc """
     Event generated when a team is eliminated in Knockout Mode.
     """
     use GameBot.Domain.Events.BaseEvent, type: "team_eliminated", version: 1
     
     @required_fields [:game_id, :team_id, :round_number, :reason, :metadata, :timestamp]
     defstruct @required_fields ++ [:final_score, :player_stats, :final_state, :mode]
     
     @impl true
     def validate(event) do
       with :ok <- EventStructure.validate_fields(event, @required_fields),
            :ok <- super(event) do
         :ok
       end
     end
     
     # Constructor
     def new(game_id, team_id, round_number, reason, metadata, opts \\ []) do
       %__MODULE__{
         game_id: game_id,
         team_id: team_id,
         round_number: round_number,
         reason: reason,
         final_score: Keyword.get(opts, :final_score, 0),
         player_stats: Keyword.get(opts, :player_stats, %{}),
         final_state: Keyword.get(opts, :final_state, %{}),
         mode: :knockout,
         metadata: metadata,
         timestamp: EventStructure.create_timestamp()
       }
     end
   end
   
   defmodule GameBot.Domain.Events.GameEvents.KnockoutRoundCompleted do
     @moduledoc """
     Event generated when a knockout round completes.
     """
     use GameBot.Domain.Events.BaseEvent, type: "knockout_round_completed", version: 1
     
     @required_fields [:game_id, :guild_id, :round_number, :remaining_teams, 
                      :eliminated_teams, :metadata, :timestamp]
     defstruct @required_fields ++ [:round_stats, :mode]
     
     @impl true
     def validate(event) do
       with :ok <- EventStructure.validate_fields(event, @required_fields),
            :ok <- super(event) do
         :ok
       end
     end
     
     # Constructor
     def new(game_id, guild_id, round_number, remaining_teams, eliminated_teams, metadata, opts \\ []) do
       %__MODULE__{
         game_id: game_id,
         guild_id: guild_id,
         round_number: round_number,
         remaining_teams: remaining_teams,
         eliminated_teams: eliminated_teams,
         round_stats: Keyword.get(opts, :round_stats, %{}),
         mode: :knockout,
         metadata: metadata,
         timestamp: EventStructure.create_timestamp()
       }
     end
   end
   ```

#### 3.3 Error Events (Day 3-4)

##### Implementation Steps
1. **Create Error Events**
   ```elixir
   # In lib/game_bot/domain/events/game_events/error_events.ex
   defmodule GameBot.Domain.Events.GameEvents.GuessError do
     @moduledoc """
     Event generated when there is an error processing a guess.
     """
     use GameBot.Domain.Events.BaseEvent, type: "guess_error", version: 1
     
     @required_fields [:game_id, :guild_id, :team_id, :player_id, :word,
                      :reason, :metadata, :timestamp]
     defstruct @required_fields
     
     @impl true
     def validate(event) do
       with :ok <- EventStructure.validate_fields(event, @required_fields),
            :ok <- validate_reason(event.reason),
            :ok <- super(event) do
         :ok
       end
     end
     
     defp validate_reason(:invalid_word), do: :ok
     defp validate_reason(:word_forbidden), do: :ok
     defp validate_reason(:guess_already_submitted), do: :ok
     defp validate_reason(_), do: {:error, "invalid error reason"}
   end
   ```

### Phase 4: Implementation in Game Modes (3 days)

#### 4.1 Update Two Player Mode (Day 1-2)

##### Implementation Steps
1. **Add Event Validation to Two Player Mode**
   ```elixir
   # In lib/game_bot/domain/game_modes/two_player_mode.ex
   
   # Add validation for Two Player Mode events
   def validate_event(event) do
     case event do
       %GameBot.Domain.Events.GameEvents.GuessProcessed{} ->
         validate_guess_processed(event)
       _ ->
         :ok
     end
   end
   
   defp validate_guess_processed(event) do
     # Two player mode-specific validation
     if event.player1_word == nil or event.player2_word == nil do
       {:error, "missing player words"}
     else
       :ok
     end
   end
   ```

2. **Update Event Generation**
   ```elixir
   # In process_guess function or similar
   
   def process_guess(state, team_id, player_id, word) do
     # ... existing logic
     
     # Create metadata with causation tracking
     metadata = Metadata.new("process_guess", 
                 guild_id: state.guild_id,
                 actor_id: player_id,
                 correlation_id: state.metadata.correlation_id)
     
     # Create the event
     guess_event = GameBot.Domain.Events.GameEvents.GuessProcessed.new(
       state.game_id,
       state.guild_id,
       state.round_number,
       team_id,
       %{player_id: player1_id, team_id: team_id},
       %{player_id: player2_id, team_id: team_id},
       player1_word,
       player2_word,
       match_score,
       is_match,
       metadata,
       guess_count: team_state.guess_count
     )
     
     # Return updated state and events
     {:ok, updated_state, [guess_event]}
   end
   ```

#### 4.2 Integration Testing (Day 2-3)

##### Implementation Steps
1. **Create Test for Event Structure**
   ```elixir
   # In test/game_bot/domain/events/event_structure_test.exs
   
   test "validates event with causation tracking" do
     metadata = %{
       source_id: "test-123",
       correlation_id: "corr-456",
       causation_id: "cause-789",
       guild_id: "guild-123"
     }
     
     event = %GameBot.Domain.Events.GameEvents.GameStarted{
       game_id: "game-123",
       guild_id: "guild-123",
       mode: :two_player,
       round_number: 1,
       teams: [],
       team_ids: [],
       player_ids: [],
       config: %{},
       metadata: metadata,
       timestamp: DateTime.utc_now()
     }
     
     assert :ok = EventStructure.validate(event)
   end
   ```

2. **Test Event Serialization**
   ```elixir
   # In test/game_bot/infrastructure/persistence/event_store/serializer_test.exs
   
   test "serializes and deserializes event with enhanced metadata" do
     metadata = %{
       source_id: "test-123",
       correlation_id: "corr-456",
       causation_id: "cause-789",
       guild_id: "guild-123"
     }
     
     original_event = %GameBot.Domain.Events.GameEvents.GameStarted{
       game_id: "game-123",
       guild_id: "guild-123",
       mode: :two_player,
       round_number: 1,
       teams: [],
       team_ids: [],
       player_ids: [],
       config: %{},
       metadata: metadata,
       timestamp: DateTime.utc_now()
     }
     
     {:ok, serialized} = GameBot.Infrastructure.Persistence.EventStore.JsonSerializer.serialize(original_event)
     {:ok, deserialized} = GameBot.Infrastructure.Persistence.EventStore.JsonSerializer.deserialize(serialized)
     
     assert deserialized.game_id == original_event.game_id
     assert deserialized.metadata.correlation_id == original_event.metadata.correlation_id
     assert deserialized.metadata.causation_id == original_event.metadata.causation_id
   end
   ```

## Testing Strategy

For each component implemented:

1. **Unit Tests**
   - Test each event module's validation
   - Test metadata creation and causation tracking
   - Test serialization/deserialization

2. **Integration Tests**
   - Test event validation in game modes
   - Test event generation and handling
   - Test complete event chains

3. **Recovery Tests**
   - Test state reconstruction from events
   - Test handling of incomplete event streams

## Implementation Tips

1. **Start with the Metadata Module**
   The enhanced metadata structure is the foundation for everything else.

2. **Use BaseEvent as a Template**
   Create the BaseEvent first, then update other event modules to follow its pattern.

3. **Implement Incrementally**
   Start with a few core events, then expand to all event types.

4. **Test Each Stage**
   Thoroughly test each component before moving to the next.

## Expected Outcomes

After completing this implementation:

1. All events will have a consistent structure
2. Event validation will be comprehensive and mode-specific
3. Causation tracking will enable better debugging
4. State recovery will be more reliable
5. Game modes will have standardized event handling

## Guess Processing Flow

### Overview

The guess processing system follows a strict sequence to ensure data consistency and proper event emission:

1. **Initial Validation**
   - Validate individual guesses as they come in
   - Store first guess as pending
   - Wait for second guess

2. **Pair Processing**
   ```elixir
   def process_guess_pair(state, team_id, guess_pair) do
     start_time = DateTime.utc_now()
     
     with :ok <- validate_guess_pair(state, team_id, guess_pair),
          state <- record_guess_pair(state, team_id, guess_pair) do

       guess_successful = player1_word == player2_word
       end_time = DateTime.utc_now()
       guess_duration = DateTime.diff(end_time, start_time, :millisecond)

       # Create event with timing and round context
       event = %GuessProcessed{
         # ... event fields ...
         guess_duration: guess_duration,
         round_guess_count: round_guess_count,
         total_guesses: total_guesses
       }

       # Update state based on result
       state = if guess_successful do
         record_match(state, team_id, word)
       else
         increment_guess_count(state, team_id)
       end

       {:ok, state, event}
     end
   end
   ```

3. **Event Emission**
   - Event is only created after all processing is complete
   - Includes timing information
   - Includes round context
   - Contains complete guess history

### Implementation Requirements

1. **Timing Tracking**
   - Record start time before processing
   - Record end time after processing
   - Calculate duration in milliseconds
   - Include in event metadata

2. **Round Context**
   - Track current round number
   - Track guesses within round
   - Track total guesses
   - Include all in event

3. **State Updates**
   - Update state atomically
   - Record matches if successful
   - Increment counters
   - Update forbidden words

4. **Validation**
   - Validate both words
   - Validate team context
   - Validate player permissions
   - Check forbidden words

### Testing Strategy

1. **Unit Tests**
   ```elixir
   describe "process_guess_pair" do
     test "includes timing information" do
       {result, state, event} = process_guess_pair(state, team_id, guess_pair)
       assert event.guess_duration > 0
     end

     test "includes round context" do
       {result, state, event} = process_guess_pair(state, team_id, guess_pair)
       assert event.round_number > 0
       assert event.round_guess_count > 0
       assert event.total_guesses >= event.round_guess_count
     end
   end
   ```

2. **Integration Tests**
   - Test complete guess flow
   - Verify state updates
   - Check event contents
   - Validate timing

3. **Performance Tests**
   - Measure processing time
   - Check event emission
   - Verify state updates
   - Test concurrent guesses

### Error Handling

1. **Validation Errors**
   - Return early with error
   - Don't update state
   - Don't emit event
   - Log failure

2. **Processing Errors**
   - Roll back state changes
   - Don't emit event
   - Log error
   - Return error tuple

3. **Recovery Strategy**
   - Clear pending guesses
   - Reset counters if needed
   - Log recovery action
   - Notify players 
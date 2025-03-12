# Per-Player Guess Timing Implementation

## Overview

Currently, our system tracks a single `guess_duration` that represents the total time taken for a guess to be completed (from initiation to both players submitting words). This implementation enhances the system to track individual timing for each player, allowing for:

- More detailed analytics on player performance
- Better understanding of team dynamics
- Enhanced replay experiences showing which player responded faster
- More granular data for matchmaking and skill assessment

## Key Timing Requirements

1. **Round-Based Timing**: All guess durations are measured from the start of the current round, not from when each guess attempt begins
2. **Per-Player Tracking**: We track each player's submission time independently
3. **Give Up Accuracy**: When a player submits "give up", we record their actual submission time, not a default value of 0
4. **Round Continuity**: Rounds do not restart on unsuccessful guesses (except when explicitly giving up in race mode or golf race mode)

## Required Changes

### 1. Database Schema Changes

#### Migration File

Create a new migration file to modify the `guesses` table:

```elixir
defmodule GameBot.Infrastructure.Repo.Migrations.AddPerPlayerGuessTiming do
  use Ecto.Migration

  def change do
    alter table(:guesses) do
      # Keep the original field for backward compatibility and total duration
      # Add new fields for individual player timing
      add :player1_duration, :integer
      add :player2_duration, :integer
    end
  end
end
```

### 2. Ecto Schema Updates

Update the `GameBot.Infrastructure.Repo.Schemas.Guess` module:

```elixir
# In game_bot/lib/game_bot/infrastructure/repo/schemas/guess.ex

schema "guesses" do
  # ... existing fields ...
  field :guess_duration, :integer          # Total duration (kept for backward compatibility)
  field :player1_duration, :integer        # Time taken by player 1
  field :player2_duration, :integer        # Time taken by player 2
  # ... 
end

@required_fields [
  # ... existing required fields ...
]
@optional_fields [
  # ... existing optional fields ...
  :player1_duration, 
  :player2_duration
]
```

### 3. Event Structure Updates

Modify the `GuessProcessed` event in `GameBot.Domain.Events.GuessEvents`:

```elixir
# In game_bot/lib/game_bot/domain/events/guess_events.ex

defmodule GuessProcessed do
  # ... existing module documentation ...
  # Add to documentation:
  # - player1_duration: Time in milliseconds player1 took to submit their word
  # - player2_duration: Time in milliseconds player2 took to submit their word
  
  @type t :: %__MODULE__{
    # ... existing fields ...
    guess_duration: non_neg_integer(),
    player1_duration: non_neg_integer(),
    player2_duration: non_neg_integer()
  }

  defstruct [
    # ... existing fields ...
    :player1_duration,
    :player2_duration
  ]

  def validate_attrs(attrs) do
    with {:ok, base_attrs} <- super(attrs),
         # ... existing validations ...
         :ok <- validate_non_negative_integer_field(attrs, :guess_duration),
         :ok <- validate_optional_non_negative_integer_field(attrs, :player1_duration),
         :ok <- validate_optional_non_negative_integer_field(attrs, :player2_duration) do
      {:ok, base_attrs}
    end
  end
  
  # Add helper validation function if not already present
  defp validate_optional_non_negative_integer_field(attrs, field) do
    case Map.get(attrs, field) do
      nil -> :ok
      value when is_integer(value) and value >= 0 -> :ok
      _ -> {:error, {:validation, "#{field} must be a non-negative integer"}}
    end
  end
end
```

### 4. Game Logic Modifications

#### A. Session Manager Updates

The session manager needs to track when each player submits their word:

```elixir
# In the game session manager (approximate implementation)

defmodule GameBot.Domain.GameSession do
  # ... existing code ...
  
  # State should include:
  # %{
  #   player1_submission_time: nil | DateTime.t(),
  #   player2_submission_time: nil | DateTime.t(),
  #   guess_start_time: nil | DateTime.t()
  # }
  
  # When starting a guess:
  def handle_start_guess(state) do
    state = %{state | 
      guess_start_time: DateTime.utc_now(),
      player1_submission_time: nil,
      player2_submission_time: nil
    }
    # ... rest of function ...
  end
  
  # When a player submits a word:
  def handle_word_submission(state, player_id, word) do
    now = DateTime.utc_now()
    
    # Update the appropriate player's submission time
    state = cond do
      player_id == state.player1_id ->
        %{state | player1_submission_time: now}
      player_id == state.player2_id ->
        %{state | player2_submission_time: now}
      true ->
        state  # Handle error case
    end
    
    # ... existing logic for both words submitted ...
    
    # If both words are submitted, calculate durations:
    if both_words_submitted?(state) do
      {updated_state, event} = process_complete_guess(state)
      # ... handling completed guess
    else
      # ... handling partial submission
    end
  end
  
  defp process_complete_guess(state) do
    # Calculate individual durations
    player1_duration = player_submission_duration(state.guess_start_time, state.player1_submission_time)
    player2_duration = player_submission_duration(state.guess_start_time, state.player2_submission_time)
    
    # Total duration from start to last submission
    total_duration = max(player1_duration, player2_duration)
    
    # ... create GuessProcessed event with these durations ...
    guess_processed_event = %GuessProcessed{
      # ... other fields ...
      guess_duration: total_duration,
      player1_duration: player1_duration,
      player2_duration: player2_duration
    }
    
    # ...
  end
  
  defp player_submission_duration(start_time, submission_time) do
    DateTime.diff(submission_time, start_time, :millisecond)
  end
end
```

#### B. RaceMode's "Give Up" Handling Update

Update the `handle_give_up` function in `RaceMode` to include player durations:

```elixir
# In game_bot/lib/game_bot/domain/game_modes/race_mode.ex

defp handle_give_up(state, team_id, guess_pair) do
  # ... existing code ...
  
  # For give-ups, set durations based on which player gave up
  {player1_duration, player2_duration} = 
    cond do
      guess_pair.player1_word == @give_up_command ->
        {0, nil}  # Player 1 gave up immediately
      guess_pair.player2_word == @give_up_command ->
        {nil, 0}  # Player 2 gave up immediately
      true ->
        {nil, nil}  # Should not happen
    end
  
  guess_processed_event = %GameBot.Domain.Events.GuessEvents.GuessProcessed{
    # ... existing fields ...
    guess_duration: 0,  # Give-ups have no meaningful total duration
    player1_duration: player1_duration,
    player2_duration: player2_duration,
    # ...
  }
  
  # ... rest of function
end
```

### 5. Replay System Updates

Update the replay system to use the individual player durations:

```elixir
# In the replay renderer

def render_guess(guess) do
  # ... existing code ...
  
  # Determine which player was faster (if both durations available)
  faster_player = cond do
    is_nil(guess.player1_duration) or is_nil(guess.player2_duration) ->
      nil
    guess.player1_duration <= guess.player2_duration ->
      guess.player1
    true ->
      guess.player2
  end
  
  # Use this information in the rendering
  # ...
end
```

## Implementation Plan

### Completed Changes

1. ✅ Added database schema changes for `player1_duration` and `player2_duration` fields
2. ✅ Updated the Guess Ecto schema to include these fields
3. ✅ Modified the GuessProcessed event structure to include the player duration fields
4. ✅ Updated BaseMode implementation to handle player duration data
5. ✅ Enhanced RaceMode's "give up" handling to record accurate submission times
6. ✅ Added round start time tracking in the Session module
7. ✅ Implemented submission time calculation from round start time
8. ✅ Updated handling of round transitions to reset timing

### Remaining Tasks

1. Add proper unit tests for the timing functionality
2. Enhance replay rendering to show per-player timing information
3. Consider adding analytics features that leverage the new timing data
4. Verify that all game modes handle the timing data consistently 

## Testing Strategy

1. **Unit Tests**:
   - Test the updated event validation
   - Test duration calculation functions
   
2. **Integration Tests**:
   - Test the flow from word submission to GuessProcessed event
   - Verify durations are calculated and stored correctly
   
3. **System Tests**:
   - Test complete game sessions and verify timing data
   - Test replay functionality with the new timing data

## Backward Compatibility

This change maintains backward compatibility by:

1. Keeping the original `guess_duration` field
2. Making the new `player1_duration` and `player2_duration` fields optional
3. Ensuring older event formats can still be processed

## Performance Considerations

The additional timing fields add minimal overhead:

- Two additional integer fields in the database (8-16 bytes per record)
- Two additional integer fields in events (8-16 bytes per event)
- Negligible additional computation for tracking submissions

## Future Enhancements

Once per-player timing is implemented, we could consider:

1. Player speed statistics and leaderboards
2. Visual indicators during replay showing which player submitted first
3. Advanced analytics on team dynamics based on response patterns
4. Adaptive difficulty based on player response times 
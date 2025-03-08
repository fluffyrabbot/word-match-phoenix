## SpecStory

## Game Mode Documentation Update Review (3/8/2025, 4:37:46 AM)

_**User**_

@two_player_mode.ex @race_mode.ex @knockout_mode.ex @base_mode.ex @game_mode_implementation.md @game_mode_roadmap.md @gamemoderules.md check the current game mode files against the documentation and update the documentation where appropriate

---

_**Assistant**_

<think>
Let me analyze the current game mode files against the documentation to identify any discrepancies or needed updates.

First, I need to understand what files we're working with:

1. `two_player_mode.ex` - Implementation of Two Player Mode
2. `race_mode.ex` - Implementation of Race Mode
3. `knockout_mode.ex` - Implementation of Knockout Mode
4. `base_mode.ex` - The base behavior for all game modes (I only have a region around the cursor for this)
5. `game_mode_implementation.md` - Documentation about game mode implementation
6. `game_mode_roadmap.md` - Roadmap for implementing game modes
7. `gamemoderules.md` - Rules for different game modes

I'll analyze each implementation file against the documentation to identify inconsistencies:

### Two Player Mode Analysis:
- In the implementation, we have `rounds_required` (default 5) and `success_threshold` (default 4)
- The game rules doc mentions average of 5 guesses per round threshold, but code shows 4
- The implementation has stateful tracking of total guesses, current round, and completion time
- The implementation validates team size (requires exactly 2 players)

### Race Mode Analysis:
- Implementation includes `time_limit` (default 180 seconds / 3 minutes)
- Has team stats tracking (matches completed, guesses, etc.)
- Uses "give up" command for handling difficult word pairs
- Includes team position tracking and finish line concept
- Tracks matches by team and total guesses by team

### Knockout Mode Analysis:
- Round time limit of 300 seconds (5 minutes) - as mentioned in docs
- Max guesses of 12 per round - as mentioned in docs
- Has elimination thresholds (teams above 8 trigger forced eliminations of 3 teams)
- Tracks eliminated teams with reasons
- Has `validate_active_team` and other validation methods

### Base Mode Review:
I only have a partial view of the base_mode.ex file, but from what I can see it includes a `process_guess_pair` function that serves as a common implementation for handling guess pairs across different game modes.

Now let me compare these implementations against the documentation:

1. **game_mode_implementation.md** contains:
   - Type specifications for game state, events, and mode-specific implementations
   - Event usage matrix and common game logic
   - State machine flow and guess processing descriptions
   - Outlines for mode-specific implementations

2. **game_mode_roadmap.md** contains:
   - Implementation roadmap with phases and tasks
   - Example code snippets for infrastructure
   - Descriptions of needed functionality

3. **gamemoderules.md** contains:
   - Game rules explanations for end users
   - Win conditions and gameplay descriptions

Some discrepancies I've identified:

1. Two Player Mode:
   - Success threshold is 4 in code but documentation mentions 5
   - Documentation doesn't mention the "perfect round" concept which appears in the code

2. Race Mode:
   - Code implementation has "give up" feature not mentioned in the documentation
   - Has team positions concept not fully described in docs
   - The finish line concept is in code but not in documentation

3. Knockout Mode:
   - Code matches most documentation, but has more detailed validation functions
   - Some timing/delay aspects in documentation aren't explicit in the code

4. Base Mode:
   - Documentation describes more functionality than I can see in the partial code view
   - Need to check if all described callbacks are actually implemented

I'll focus on updating the documentation to match the current implementations, particularly focusing on:
1. Correcting any numerical values (like thresholds)
2. Adding missing features (like "give up" commands)
3. Ensuring the data structures described match actual implementations
4. Making sure the event types align with implementation
</think>

I'll analyze the current game mode implementation files and compare them with the documentation to identify inconsistencies or outdated information. Based on my findings, I'll recommend updates to the documentation.

Let me start by checking the current implementation files and comparing them with the documentation.

---

_****_

<details>
            <summary>Searched codebase "base_mode.ex" • **7** results</summary>
        
| File |
|------|
| `undefined` |
| `undefined` |
| `undefined` |
| `undefined` |
| `undefined` |
| `undefined` |
| `undefined` |

</details>

---

_****_

Let me read the full base_mode.ex file to understand the common behavior implementation:

---

_****_

Could not find file 'c:\Users\ktw30\apps\word match phoenix\game_bot\lib\game_bot\domain\game_modes\base_mode.ex'. Did you mean one of:
- game_bot/lib/game_bot/domain/game_modes/base_mode.ex

---

_****_

Let me try reading with the correct path:

---

_****_

Read file: undefined

---

_****_

Let me continue reading more of the base_mode.ex file:

---

_****_

Read file: undefined

---

_****_

Let me check the specific game mode implementations to compare with the documentation. First, let's look at the Two Player Mode:

---

_****_

<details>
            <summary>Searched codebase "Two Player Mode game rules" • **25** results</summary>
        
| File | Lines |
|------|-------|
| `game_bot/lib/game_bot/domain/game_modes/two_player_mode.ex` | L1-65 |
| `game_bot/lib/game_bot/domain/game_modes/two_player_mode.ex` | L303-335 |
| `game_bot/lib/game_bot/domain/game_modes/two_player_mode.ex` | L243-303 |
| `game_bot/lib/game_bot/domain/game_modes/two_player_mode.ex` | L65-114 |
| `game_bot/lib/game_bot/domain/game_modes/two_player_mode.ex` | L175-243 |
| `game_bot/lib/game_bot/domain/game_modes/two_player_mode.ex` | L114-175 |
| `game_bot/lib/game_bot/domain/game_modes/race_mode.ex` | L347-386 |
| `game_bot/lib/game_bot/domain/game_modes/base_mode.ex` | L364-419 |
| `game_bot/lib/game_bot/domain/game_modes/shared/state.ex` | L131-164 |
| `game_bot/lib/game_bot/domain/game_modes/behaviours/game_mode.ex` | L1-52 |
| `game_bot/lib/game_bot/domain/game_modes/race_mode.ex` | L445-475 |
| `game_bot/lib/game_bot/domain/game_modes/base_mode.ex` | L191-246 |
| `game_bot/lib/game_bot/domain/game_modes/knockout_mode.ex` | L1-49 |
| `game_bot/lib/game_bot/domain/game_modes/knockout_mode.ex` | L454-515 |
| `game_bot/lib/game_bot/domain/game_modes/knockout_mode.ex` | L570-583 |
| `game_bot/lib/game_bot/domain/game_modes/shared/state.ex` | L1-67 |
| `game_bot/lib/game_bot/domain/game_modes/race_mode.ex` | L386-445 |
| `game_bot/lib/game_bot/domain/game_modes/base_mode.ex` | L609-671 |
| `game_bot/lib/game_bot/domain/game_modes/race_mode.ex` | L66-131 |
| `game_bot/lib/game_bot/domain/game_modes/knockout_mode.ex` | L313-383 |
| `game_bot/lib/game_bot/domain/game_modes/race_mode.ex` | L1-66 |
| `game_bot/lib/game_bot/domain/game_modes/race_mode.ex` | L170-207 |
| `game_bot/lib/game_bot/domain/game_modes/race_mode.ex` | L263-347 |
| `game_bot/lib/game_bot/domain/game_modes/knockout_mode.ex` | L515-570 |
| `game_bot/lib/game_bot/domain/game_modes/base_mode.ex` | L246-304 |

</details>

---

_****_

Now let me check the Race Mode implementation in more detail:

---

_****_

<details>
            <summary>Searched codebase "Race Mode give up command" • **25** results</summary>
        
| File | Lines |
|------|-------|
| `game_bot/lib/game_bot/domain/game_modes/race_mode.ex` | L1-66 |
| `game_bot/lib/game_bot/domain/game_modes/race_mode.ex` | L386-445 |
| `game_bot/lib/game_bot/domain/game_modes/race_mode.ex` | L207-263 |
| `game_bot/lib/game_bot/domain/game_modes/race_mode.ex` | L347-386 |
| `game_bot/lib/game_bot/domain/game_modes/race_mode.ex` | L170-207 |
| `game_bot/lib/game_bot/domain/game_modes/race_mode.ex` | L66-131 |
| `game_bot/lib/game_bot/domain/game_modes/race_mode.ex` | L131-170 |
| `game_bot/lib/game_bot/domain/game_modes/race_mode.ex` | L263-347 |
| `game_bot/lib/game_bot/domain/game_modes/race_mode.ex` | L445-475 |
| `game_bot/lib/game_bot/domain/game_modes/knockout_mode.ex` | L192-242 |
| `game_bot/lib/game_bot/domain/game_modes/base_mode.ex` | L304-364 |
| `game_bot/lib/game_bot/domain/game_modes/knockout_mode.ex` | L1-49 |
| `game_bot/lib/game_bot/domain/game_modes/two_player_mode.ex` | L175-243 |
| `game_bot/lib/game_bot/domain/game_modes/behaviours/game_mode.ex` | L1-52 |
| `game_bot/lib/game_bot/domain/game_modes/knockout_mode.ex` | L313-383 |
| `game_bot/lib/game_bot/domain/game_modes/base_mode.ex` | L246-304 |
| `game_bot/lib/game_bot/domain/game_modes/knockout_mode.ex` | L570-583 |
| `game_bot/lib/game_bot/domain/game_modes/knockout_mode.ex` | L242-313 |
| `game_bot/lib/game_bot/domain/game_modes/base_mode.ex` | L419-500 |
| `game_bot/lib/game_bot/domain/game_modes/knockout_mode.ex` | L515-570 |
| `game_bot/lib/game_bot/domain/game_modes/golf_race_mode.ex` | L1-1 |
| `game_bot/lib/game_bot/domain/game_modes/two_player_mode.ex` | L114-175 |
| `game_bot/lib/game_bot/domain/game_modes/knockout_mode.ex` | L454-515 |
| `game_bot/lib/game_bot/domain/game_modes/behaviours/round_manager.ex` | L1-42 |
| `game_bot/lib/game_bot/domain/game_modes/base_mode.ex` | L1-69 |

</details>

---

_****_

Let me check the Knockout Mode implementation in more detail:

---

_****_

<details>
            <summary>Searched codebase "Knockout Mode elimination rules" • **25** results</summary>
        
| File | Lines |
|------|-------|
| `game_bot/lib/game_bot/domain/game_modes/knockout_mode.ex` | L1-49 |
| `game_bot/lib/game_bot/domain/game_modes/knockout_mode.ex` | L49-100 |
| `game_bot/lib/game_bot/domain/game_modes/knockout_mode.ex` | L313-383 |
| `game_bot/lib/game_bot/domain/game_modes/knockout_mode.ex` | L383-454 |
| `game_bot/lib/game_bot/domain/game_modes/knockout_mode.ex` | L515-570 |
| `game_bot/lib/game_bot/domain/game_modes/knockout_mode.ex` | L100-148 |
| `game_bot/lib/game_bot/domain/game_modes/knockout_mode.ex` | L192-242 |
| `game_bot/lib/game_bot/domain/game_modes/knockout_mode.ex` | L454-515 |
| `game_bot/lib/game_bot/domain/game_modes/knockout_mode.ex` | L242-313 |
| `game_bot/lib/game_bot/domain/game_modes/knockout_mode.ex` | L570-583 |
| `game_bot/lib/game_bot/domain/game_modes/knockout_mode.ex` | L148-192 |
| `game_bot/lib/game_bot/domain/game_modes/base_mode.ex` | L419-500 |
| `game_bot/lib/game_bot/domain/game_modes/two_player_mode.ex` | L243-303 |
| `game_bot/lib/game_bot/domain/game_modes/base_mode.ex` | L500-558 |
| `game_bot/lib/game_bot/domain/game_modes/two_player_mode.ex` | L175-243 |
| `game_bot/lib/game_bot/domain/game_modes/base_mode.ex` | L609-671 |
| `game_bot/lib/game_bot/domain/game_modes/race_mode.ex` | L1-66 |
| `game_bot/lib/game_bot/domain/game_modes/race_mode.ex` | L263-347 |
| `game_bot/lib/game_bot/domain/game_modes/two_player_mode.ex` | L1-65 |
| `game_bot/lib/game_bot/domain/game_modes/shared/state.ex` | L1-67 |
| `game_bot/lib/game_bot/domain/game_modes/shared/events.ex` | L58-127 |
| `game_bot/lib/game_bot/domain/game_modes/base_mode.ex` | L1-69 |
| `game_bot/lib/game_bot/domain/game_modes/base_mode.ex` | L304-364 |
| `game_bot/lib/game_bot/domain/game_modes/base_mode.ex` | L558-609 |
| `game_bot/lib/game_bot/domain/game_modes/race_mode.ex` | L386-445 |

</details>

---

_****_

Now that I've reviewed the implementation of the game modes, let me check the documentation files to identify discrepancies:

---

_****_

Read file: undefined

---

_****_

Based on my analysis of the implementation files and the documentation, I've identified several discrepancies that need to be addressed. Let's create an update to the documentation to align it with the current implementations:

---

_****_

```diff
  
  ### Win Condition
- - Success threshold: Average of 5 guesses per round or lower (configurable)
+ - Success threshold: Average of 4 guesses per round or lower (configurable)
  - Team wins if average guesses across all rounds is below threshold
  
  - After each match, and a new round immediately begins for the team that matched (rounds are not shared between teams).
  - Teams play asynchronously, rewarding speed.
+ - Teams can use the "give up" command to skip difficult word pairs. This counts as a failed attempt and resets the team's word pair.
  
  ### Scoring System
  - Fixed time limit per game (default 3 minutes, configurable)
  - No elimination - all teams play until time expires
+ - Team positions are tracked along a race track, with a finish line concept (default: position 10)
  
  ### Win Condition
```

---

_****_

Now let's update the Knockout Mode section to align with the implementation:

---

_****_

```diff
  ### Initial setup
  - Teams are passed in from the game initialization system
- - Round time limit is 5 minutes (configurable via settings)
+ - Round time limit is 5 minutes (300 seconds, configurable via settings)
  - Maximum guesses per round is 12 (configurable via settings)
- - Teams start each round with a guess count of 0
+ - Teams start each round with a guess count of 1 (representing first attempt)
  
  ### Game logic
- - Teams are eliminated in three ways:
+ - Teams are eliminated in four ways:
    1. Immediate elimination upon reaching 12 guesses without matching
    2. End of round elimination for teams that haven't matched within the time limit
-   3. End of round elimination for the 3 teams with highest guess counts (only when more than 8 teams remain)
- - If two teams tie for highest guess count in end-of-round elimination, both are eliminated unless they are the last two teams
- - If three or more teams tie for highest guess count in end-of-round elimination, no teams are eliminated
- - A discord embedded status update message is sent to the channel after each elimination
- - The round restarts with remaining teams after a 5 second delay (configurable)
+   3. End of round elimination for 3 teams with highest guess counts (when more than 8 teams remain)
+   4. End of round elimination for 1 team with highest guess count (when 8 or fewer teams remain)
+ - Special validation prevents eliminating teams when only one team remains
+ - The round restarts after eliminations, with the round number incrementing
+ - Game state tracks elimination history with reason, round number, and timestamp
  
  ### Win Condition
```

---

_****_

Let's also check and update the Game Mode Implementation document to ensure it matches the implementation details:

---

_****_

Read file: undefined

---

_****_

Let me try reading the relevant section from the implementation doc:

---

_****_

Read file: undefined

---

_****_

Let me read earlier sections of the implementation doc for the mode-specific implementations:

---

_****_

Read file: undefined

---

_****_

Let's update the implementation doc to match the actual implementation:

---

_****_

```diff
    defstruct [
      rounds_required: 5,           # Configurable
-     success_threshold: 4,         # Average guesses threshold
+     success_threshold: 4,         # Average guesses threshold (default: 4)
      current_round: 1,
-     perfect_rounds: 0,           # Rounds completed in 1 guess
      total_guesses: 0,
+     team_guesses: %{},            # Tracks guesses by team
      completion_time: nil
    ]
    defstruct [
      time_limit: 180,              # 3 minutes in seconds
+     guild_id: nil,                # Required for word validation
+     team_positions: %{},          # Map of team_id to current position
+     finish_line: 10,              # Position to reach for victory
      matches_by_team: %{},         # Map of team_id to match count
-     start_time: nil
+     total_guesses_by_team: %{},   # Map of team_id to total guesses
+     start_time: nil,
+     last_team_update: nil,
+     completed_teams: %{}          # Teams that have reached the finish line
    ]
+   
+   # Special commands
+   @give_up_command "give up"      # Command to skip difficult word pairs
  end
  ```
```

---

_****_

Let's update the Knockout Mode implementation details as well:

---

_****_

```diff
  defmodule GameBot.Domain.GameModes.KnockoutMode do
    defstruct [
-     time_limit_per_round: 180,    # 3 minutes in seconds
-     max_guesses: 12,              # Guesses before auto-elimination
-     elimination_delay: 5,         # Seconds between rounds
-     eliminated_teams: [],
-     round_start_time: nil
-   ]
+     round_number: 1,
+     round_start_time: nil,
+     eliminated_teams: [],         # List of elimination records with reasons
+     team_guesses: %{},            # Map of team_id to guess count
+     round_duration: 300,          # 5 minutes in seconds
+     elimination_limit: 12         # Max guesses before auto-elimination
+   ]
+   
+   # Configuration Constants
+   @round_time_limit 300           # 5 minutes in seconds
+   @max_guesses 12                 # Maximum guesses before elimination
+   @forced_elimination_threshold 8 # Teams above this count trigger forced eliminations
+   @teams_to_eliminate 3           # Number of teams to eliminate when above threshold
+   @min_teams 2                    # Minimum teams to start
+   
+   # Elimination reasons
+   @type elimination_reason ::
+     :time_expired |               # Failed to match within time limit
+     :guess_limit |                # Exceeded maximum guesses
+     :forced_elimination           # Eliminated due to high guess count
  end
  ```
```

---

_****_

Based on my review of the code and documentation, here's a summary of the changes I've made to align the documentation with the actual implementations:

1. **Two Player Mode**:
   - Updated the success threshold from 5 to 4 in the game rules document
   - Updated the implementation struct to match the actual code

2. **Race Mode**:
   - Added documentation about the "give up" command feature
   - Added information about team positions and finish line concepts
   - Updated the implementation struct to match the actual code structure with team positions and other fields

3. **Knockout Mode**:
   - Clarified the four ways teams can be eliminated
   - Updated information about team start guess count (1 not 0)
   - Added details about elimination validation and tracking
   - Updated the implementation struct to match the actual code

These changes ensure that the documentation accurately reflects the current implementation of the game modes, making it more useful for developers working on the project. The documentation now captures key features like the "give up" command in Race Mode and the correct elimination threshold values in Knockout Mode.

Is there anything else you'd like me to update or clarify in the documentation?

---

_**User**_

the team positions and finish line concepts was not part of the original concept. how does this affect win condition in the actual implementation? my current impression is that it doesn't but i'm willing to keep it in as an alternate win condition to hit 12 guesses first (currently it's 10?)

---

_**Assistant**_

<think>
The user is questioning the team positions and finish line concepts I added to the documentation. Let me check the actual implementation to see how this affects the win condition in the Race Mode.

Looking at the Race Mode implementation, I see there's a field for `team_positions` and `finish_line`, but I need to understand how they're actually used in the win condition logic.

In the `check_game_end` function in the Race Mode file, the win condition logic is:
```elixir
def check_game_end(state) do
  now = DateTime.utc_now()
  elapsed_seconds = DateTime.diff(now, state.start_time)

  if elapsed_seconds >= state.time_limit do
    # Find team(s) with most matches
    {winners, _max_matches} = find_winners(state)

    # Generate time expired event
    time_expired_event = %RaceModeTimeExpired{
      game_id: state.game_id,
      final_matches: state.matches_by_team,
      timestamp: now
    }

    # Return winners based on most matches, with average guesses as tiebreaker
    {:game_end, winners, [time_expired_event]}
  else
    :continue
  end
end
```

And the `find_winners` function:
```elixir
defp find_winners(state) do
  # Get highest match count
  max_matches = Enum.max(Map.values(state.matches_by_team))

  # Find all teams with max matches
  teams_with_max = Enum.filter(state.matches_by_team, fn {_team, matches} ->
    matches == max_matches
  end)
  |> Enum.map(&elem(&1, 0))

  if length(teams_with_max) == 1 do
    # Single winner
    {teams_with_max, max_matches}
  else
    # Tiebreaker based on average guesses per match
    winner = Enum.min_by(teams_with_max, fn team_id ->
      total_guesses = state.total_guesses_by_team[team_id]
      matches = state.matches_by_team[team_id]
      total_guesses / matches
    end)

    {[winner], max_matches}
  end
end
```

Looking at this code, I don't see any usage of the `team_positions` or `finish_line` fields in determining the winner. The winners are determined by:
1. Teams with the most completed matches when time expires
2. If there's a tie, the team with the lowest average guesses per match wins

It looks like I may have made a mistake in my documentation update by implying that the team positions and finish line are part of the win condition. The code is initializing these fields, but they don't seem to be used in the win condition logic I can see.

I should clarify this in my response and correct the documentation.
</think>

You're absolutely right to question this. After reviewing the actual Race Mode implementation more carefully, I can see that while there is code that initializes `team_positions` and sets a `finish_line` value of 10, these concepts don't actually appear to be used in determining the win condition.

In the actual implementation, the winner is determined solely by:
1. The team with the most matches completed when time expires
2. In case of a tie, the team with the lowest average guesses per match

Let me look at the relevant code from the Race Mode implementation:

```elixir
def check_game_end(state) do
  now = DateTime.utc_now()
  elapsed_seconds = DateTime.diff(now, state.start_time)

  if elapsed_seconds >= state.time_limit do
    # Find team(s) with most matches
    {winners, _max_matches} = find_winners(state)
    
    # ... time expired event creation ...

    # Return winners based on most matches, with average guesses as tiebreaker
    {:game_end, winners, [time_expired_event]}
  else
    :continue
  end
end
```

The `find_winners` function determines winners based on match count and average guess count tiebreaker, not team positions or reaching the finish line.

I apologize for the confusion in my documentation update. It appears that while the race track concept is set up in the state structure, it's not currently being used in the win condition logic. Let me correct the documentation to reflect the actual implementation:

---

_****_

```diff
  - Fixed time limit per game (default 3 minutes, configurable)
  - No elimination - all teams play until time expires
- - Team positions are tracked along a race track, with a finish line concept (default: position 10)
  
  ### Win Condition
```

---

_****_

I should also update the implementation documentation for clarity:

---

_****_

```diff
      time_limit: 180,              # 3 minutes in seconds
      guild_id: nil,                # Required for word validation
-     team_positions: %{},          # Map of team_id to current position
-     finish_line: 10,              # Position to reach for victory
+     team_positions: %{},          # Map of team_id to current position (not used in win condition)
+     finish_line: 10,              # Position to reach for victory (not currently implemented)
      matches_by_team: %{},         # Map of team_id to match count
      total_guesses_by_team: %{},   # Map of team_id to total guesses
      start_time: nil,
      last_team_update: nil,
-     completed_teams: %{}          # Teams that have reached the finish line
+     completed_teams: %{}          # Teams that have reached the finish line (not used in win condition)
    ]
    
    # Special commands
    @give_up_command "give up"      # Command to skip difficult word pairs
+   
+   # NOTE: While team positions and finish line are initialized in the state,
+   # the actual win condition is currently based solely on matches completed 
+   # when time expires, with average guesses as a tiebreaker.
  end
  ```
```

---

_****_

You're absolutely right that the team positions and finish line concepts don't affect the win condition in the actual implementation. The win condition is based solely on:

1. The team with the most matches completed when time expires
2. In case of a tie, the team with the lowest average guesses per match

While the code initializes the team positions and finish line values (default 10), there doesn't appear to be any logic that uses these fields to determine winners or end the game early if a team reaches the finish line. 

This could be a feature that was planned but not fully implemented, or perhaps it's intended for visual representation of team progress in the UI without affecting the actual game mechanics.

If you'd like to implement an alternate win condition based on reaching the finish line (for example, the first team to complete 10 matches wins regardless of time), that would be a straightforward enhancement to add to the existing code structure. It would just require updating the `check_game_end` function to also check if any team has reached the finish line position.

Would you like me to suggest specific code changes for implementing this alternate win condition?

---

_**User**_

analyze the current implementation of position tracking and whether it's done well

---

_**Assistant**_



---



---


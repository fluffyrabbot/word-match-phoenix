# Knockout Mode Implementation Draft

## Overview

Knockout Mode is an elimination-based game mode where teams compete in rounds. Each round has a 5-minute time limit and a 12-guess limit. Teams are eliminated in three ways:
1. Reaching 12 guesses without matching
2. Not matching within the 5-minute time limit
3. Being among the 3 teams with the highest guess counts at round end (only when more than 8 teams remain)

## Core Components

### State Structure
```elixir
defmodule State do
  defstruct [
    :game_id,
    :teams,             # Map of team_id => team_state
    :round_number,      # Current round number
    :round_start_time,  # Start time of current round
    :eliminated_teams   # List of eliminated team IDs with elimination data
  ]
end

defmodule EliminationData do
  defstruct [
    :team_id,
    :round_number,
    :reason,           # :time_expired | :guess_limit | :forced_elimination
    :guess_count,      # Number of guesses used when eliminated
    :eliminated_at     # Timestamp of elimination
  ]
end
```

### Constants
```elixir
@round_time_limit 300  # 5 minutes in seconds
@max_guesses 12       # Maximum guesses before elimination
@forced_elimination_threshold 8  # Teams above this count trigger forced eliminations
@teams_to_eliminate 3  # Number of teams to eliminate when above threshold
```

### Core Functions

```elixir
@impl true
def init(game_id, teams, _config) do
  {:ok, %State{
    game_id: game_id,
    teams: teams,
    round_number: 1,
    round_start_time: DateTime.utc_now(),
    eliminated_teams: []
  }}
end

@impl true
def process_guess_pair(state, team_id, guess_pair) do
  with {:ok, state, event} <- GameBot.Domain.GameModes.BaseMode.process_guess_pair(state, team_id, guess_pair) do
    cond do
      event.guess_successful ->
        # Reset guess count for next round
        state = update_in(state.teams[team_id], &%{&1 | guess_count: 0})
        {:ok, state, event}
      
      event.guess_count >= @max_guesses ->
        # Eliminate team for exceeding guess limit
        now = DateTime.utc_now()
        elimination_data = %EliminationData{
          team_id: team_id,
          round_number: state.round_number,
          reason: :guess_limit,
          guess_count: event.guess_count,
          eliminated_at: now
        }
        
        state = %{state |
          teams: Map.delete(state.teams, team_id),
          eliminated_teams: [elimination_data | state.eliminated_teams]
        }
        {:ok, state, event}
        
      true ->
        {:ok, state, event}
    end
  end
end

@impl true
def check_round_end(state) do
  now = DateTime.utc_now()
  elapsed_seconds = DateTime.diff(now, state.round_start_time)

  if elapsed_seconds >= @round_time_limit do
    # Handle round time expiry
    state = handle_round_time_expired(state)
    
    # Start new round if game continues
    case check_game_end(state) do
      :continue ->
        state = %{state |
          round_number: state.round_number + 1,
          round_start_time: now
        }
        {:round_end, state}
      {:game_end, winners} ->
        {:game_end, winners}
    end
  else
    :continue
  end
end

# Helper Functions

defp handle_round_time_expired(state) do
  # First eliminate teams that haven't matched
  state = eliminate_unmatched_teams(state)
  
  # Then eliminate worst performing teams if above threshold
  active_team_count = count_active_teams(state)
  if active_team_count > @forced_elimination_threshold do
    eliminate_worst_teams(state, @teams_to_eliminate)
  else
    state
  end
end

defp eliminate_unmatched_teams(state) do
  now = DateTime.utc_now()
  
  {eliminated, remaining} = Enum.split_with(state.teams, fn {_id, team} ->
    !team.current_match_complete
  end)
  
  eliminated_data = Enum.map(eliminated, fn {team_id, team} ->
    %EliminationData{
      team_id: team_id,
      round_number: state.round_number,
      reason: :time_expired,
      guess_count: team.guess_count,
      eliminated_at: now
    }
  end)
  
  %{state |
    teams: Map.new(remaining),
    eliminated_teams: state.eliminated_teams ++ eliminated_data
  }
end

defp eliminate_worst_teams(state, count) do
  now = DateTime.utc_now()
  
  # Sort teams by guess count (highest first)
  sorted_teams = Enum.sort_by(state.teams, fn {_id, team} -> 
    team.guess_count
  end, :desc)
  
  # Take the specified number of teams to eliminate
  {to_eliminate, to_keep} = Enum.split(sorted_teams, count)
  
  eliminated_data = Enum.map(to_eliminate, fn {team_id, team} ->
    %EliminationData{
      team_id: team_id,
      round_number: state.round_number,
      reason: :forced_elimination,
      guess_count: team.guess_count,
      eliminated_at: now
    }
  end)
  
  %{state |
    teams: Map.new(to_keep),
    eliminated_teams: state.eliminated_teams ++ eliminated_data
  }
end

defp count_active_teams(state) do
  map_size(state.teams)
end
```

### Events

#### KnockoutRoundStarted
- `game_id`: Game identifier
- `round_number`: Current round number
- `active_teams`: List of active team IDs
- `timestamp`: Start time of round

#### TeamEliminated
- `game_id`: Game identifier
- `team_id`: Eliminated team's ID
- `round_number`: Round when eliminated
- `reason`: Reason for elimination
- `guess_count`: Number of guesses used
- `timestamp`: Time of elimination

#### KnockoutRoundCompleted
- `game_id`: Game identifier
- `round_number`: Completed round number
- `eliminated_teams`: List of teams eliminated this round
- `remaining_teams`: List of teams advancing
- `timestamp`: End time of round

## Validation Functions

```elixir
defp validate_active_team(state, team_id) do
  if Map.has_key?(state.teams, team_id) do
    :ok
  else
    {:error, :team_eliminated}
  end
end

defp validate_round_time(state) do
  elapsed = DateTime.diff(DateTime.utc_now(), state.round_start_time)
  if elapsed < @round_time_limit do
    :ok
  else
    {:error, :round_time_expired}
  end
end

# Status Generation Helpers

defp generate_round_status(state) do
  active_count = count_active_teams(state)
  time_remaining = @round_time_limit - DateTime.diff(DateTime.utc_now(), state.round_start_time)
  eliminations_needed = if active_count > @forced_elimination_threshold, do: @teams_to_eliminate, else: 0
  
  teams_by_guesses = Enum.sort_by(state.teams, fn {_id, team} -> team.guess_count end, :desc)
  
  %{
    round_number: state.round_number,
    time_remaining: time_remaining,
    active_teams: format_team_status(teams_by_guesses),
    eliminations_needed: eliminations_needed,
    eliminated_this_round: get_eliminated_this_round(state)
  }
end

defp format_team_status(teams) do
  Enum.map(teams, fn {team_id, team} ->
    %{
      team_id: team_id,
      guess_count: team.guess_count,
      matched: team.current_match_complete
    }
  end)
end

defp get_eliminated_this_round(state) do
  Enum.filter(state.eliminated_teams, & &1.round_number == state.round_number)
  |> Enum.map(fn elimination ->
    %{
      team_id: elimination.team_id,
      reason: elimination.reason,
      guess_count: elimination.guess_count
    }
  end)
end

defp format_elimination_summary(state) do
  state.eliminated_teams
  |> Enum.group_by(& &1.round_number)
  |> Enum.sort_by(fn {round, _} -> round end)
  |> Enum.map(fn {round, eliminations} ->
    %{
      round: round,
      eliminations: Enum.map(eliminations, fn e ->
        %{
          team_id: e.team_id,
          reason: e.reason,
          guess_count: e.guess_count
        }
      end)
    }
  end)
end
```

## Elimination Reasons

Teams can be eliminated for the following reasons:

1. `:guess_limit` - The team reached 12 guesses without matching their words
2. `:time_expired` - The team failed to match their words before the 5-minute round timer expired
3. `:forced_elimination` - The team was among the 3 teams with the highest guess counts when more than 8 teams remained active

## Status Message Examples

### Round Status
```elixir
# Example usage:
status = generate_round_status(state)

# Sample output:
%{
  round_number: 2,
  time_remaining: 180,  # seconds
  active_teams: [
    %{team_id: "team1", guess_count: 5, matched: false},
    %{team_id: "team2", guess_count: 3, matched: true},
    # ...
  ],
  eliminations_needed: 3,
  eliminated_this_round: [
    %{team_id: "team5", reason: :time_expired, guess_count: 8},
    # ...
  ]
}
```

### Elimination History
```elixir
# Example usage:
history = format_elimination_summary(state)

# Sample output:
[
  %{
    round: 1,
    eliminations: [
      %{team_id: "team3", reason: :time_expired, guess_count: 7},
      %{team_id: "team4", reason: :forced_elimination, guess_count: 6}
    ]
  },
  # ...
]
```
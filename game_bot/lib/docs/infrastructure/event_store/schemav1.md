# Event Schema Documentation

## Common Types

### Metadata
```elixir
%{
  optional(:client_version) => String.t(),
  optional(:server_version) => String.t(),
  optional(:correlation_id) => String.t(),
  optional(:causation_id) => String.t(),
  optional(:user_agent) => String.t(),
  optional(:ip_address) => String.t()
}
```

### Team Info
```elixir
%{
  team_id: String.t(),
  player_ids: [String.t()],
  team_state: %{
    guess_count: non_neg_integer(),
    current_match_complete: boolean(),
    pending_guess: map() | nil,
    current_words: [String.t()]
  }
}
```

### Player Info
```elixir
%{
  player_id: String.t(),
  team_id: String.t(),
  role: atom()
}
```

## Event Schemas

### GameStarted (v1)
```elixir
%{
  game_id: String.t(),
  mode: atom(),
  round_number: 1,                          # Always 1 for game start
  teams: %{String.t() => [String.t()]},    # team_id => [player_ids]
  team_ids: [String.t()],                  # Ordered list
  player_ids: [String.t()],                # Ordered list
  roles: %{String.t() => atom()},          # player_id => role
  config: %{                               # Mode-specific config
    round_time_limit: pos_integer(),       # Seconds
    max_guesses: pos_integer() | nil,      # nil for modes without guess limits
    forced_elimination_threshold: pos_integer() | nil,  # For knockout mode
    teams_to_eliminate: pos_integer() | nil            # For knockout mode
  },
  timestamp: DateTime.t(),
  metadata: metadata()
}
```

### RoundStarted (v1)
```elixir
%{
  game_id: String.t(),
  mode: atom(),
  round_number: pos_integer(),
  team_states: %{String.t() => %{         # Initial round states
    guess_count: non_neg_integer(),
    current_match_complete: boolean(),
    pending_guess: map() | nil,
    current_words: [String.t()]
  }},
  round_config: %{                        # Round-specific configuration
    time_limit: pos_integer(),            # Seconds
    max_guesses: pos_integer() | nil,     # nil for modes without guess limits
    elimination_threshold: pos_integer() | nil  # For knockout mode
  },
  timestamp: DateTime.t(),
  metadata: metadata()
}
```

### GuessProcessed (v1)
```elixir
%{
  game_id: String.t(),
  mode: atom(),
  round_number: pos_integer(),
  team_id: String.t(),
  player1_info: player_info(),
  player2_info: player_info(),
  player1_word: String.t(),
  player2_word: String.t(),
  guess_successful: boolean(),
  guess_count: pos_integer(),
  match_score: integer(),
  timestamp: DateTime.t(),
  metadata: metadata()
}
```

### GuessAbandoned (v1)
```elixir
%{
  game_id: String.t(),
  mode: atom(),
  round_number: pos_integer(),
  team_id: String.t(),
  player1_info: player_info(),
  player2_info: player_info(),
  reason: :timeout | :player_quit | :disconnected,
  abandoning_player_id: String.t(),
  last_guess: %{
    player_id: String.t(),
    word: String.t(),
    timestamp: DateTime.t()
  } | nil,
  guess_count: pos_integer(),
  timestamp: DateTime.t(),
  metadata: metadata()
}
```

### TeamEliminated (v1)
```elixir
%{
  game_id: String.t(),
  mode: atom(),
  round_number: pos_integer(),
  team_id: String.t(),
  reason: :guess_limit | :time_expired | :forced_elimination | :forfeit,
  elimination_data: %{
    guess_count: non_neg_integer(),
    match_complete: boolean(),
    round_position: pos_integer() | nil,  # Position in forced elimination (1-3)
    time_remaining: integer() | nil       # Seconds remaining in round if applicable
  },
  final_state: team_info(),
  final_score: integer(),
  player_stats: %{String.t() => %{
    total_guesses: integer(),
    successful_matches: integer(),
    abandoned_guesses: integer(),
    average_guess_count: float()
  }},
  timestamp: DateTime.t(),
  metadata: metadata()
}
```

### GameCompleted (v1)
```elixir
%{
  game_id: String.t(),
  mode: atom(),
  round_number: pos_integer(),
  winners: [String.t()],
  final_scores: %{String.t() => %{
    score: integer(),
    matches: integer(),
    total_guesses: integer(),
    average_guesses: float(),
    player_stats: %{String.t() => %{
      total_guesses: integer(),
      successful_matches: integer(),
      abandoned_guesses: integer(),
      average_guess_count: float()
    }}
  }},
  game_duration: integer(),
  total_rounds: pos_integer(),
  timestamp: DateTime.t(),
  metadata: metadata()
}
```

### KnockoutRoundCompleted (v1)
```elixir
%{
  game_id: String.t(),
  mode: atom(),
  round_number: pos_integer(),
  eliminations: %{
    time_expired: [%{                    # Teams that didn't match in time
      team_id: String.t(),
      guess_count: non_neg_integer(),
      final_state: team_info()
    }],
    guess_limit: [%{                     # Teams that hit guess limit
      team_id: String.t(),
      guess_count: non_neg_integer(),
      final_state: team_info()
    }],
    forced: [%{                          # Teams eliminated by performance
      team_id: String.t(),
      guess_count: non_neg_integer(),
      rank: pos_integer(),               # 1-3 for worst performing
      final_state: team_info()
    }]
  },
  advancing_teams: [%{
    team_id: String.t(),
    guess_count: non_neg_integer(),
    match_complete: boolean()
  }],
  round_duration: integer(),
  timestamp: DateTime.t(),
  metadata: metadata()
}
```

### RaceModeTimeExpired (v1)
```elixir
%{
  game_id: String.t(),
  mode: atom(),
  round_number: pos_integer(),
  final_matches: %{String.t() => %{
    matches: integer(),
    total_guesses: integer(),
    average_guesses: float(),
    last_match_timestamp: DateTime.t(),
    player_stats: %{String.t() => map()}
  }},
  game_duration: integer(),
  timestamp: DateTime.t(),
  metadata: metadata()
}
```

### LongformDayEnded (v1)
```elixir
%{
  game_id: String.t(),
  mode: atom(),
  round_number: pos_integer(),
  day_number: pos_integer(),
  team_standings: %{String.t() => %{
    score: integer(),
    matches: integer(),
    total_guesses: integer(),
    average_guesses: float(),
    daily_matches: integer(),
    daily_guesses: integer(),
    player_stats: %{String.t() => map()}
  }},
  eliminated_teams: [String.t()],
  day_duration: integer(),
  timestamp: DateTime.t(),
  metadata: metadata()
} 
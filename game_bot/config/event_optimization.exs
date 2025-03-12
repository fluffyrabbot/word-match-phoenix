import Config

# Event Optimization Configuration
#
# This file contains settings for optimizing event storage to reduce disk space usage.
# These settings can be adjusted based on your specific requirements and hardware constraints.

config :game_bot, :event_optimization,
  # Master switch for all optimization features
  enabled: true,

  # Compression settings
  compression_enabled: true,
  compression_level: 6,  # 1-9, higher = better compression but slower

  # Metadata optimization settings
  metadata_optimization_enabled: true,

  # Event aggregation settings (for high-frequency events)
  aggregation_enabled: true,
  aggregation_interval: :timer.seconds(5),  # How often to aggregate events
  aggregation_batch_size: 100,  # Maximum events to aggregate in one batch

  # Event types to aggregate (high-frequency events)
  aggregation_event_types: [
    "guess_made",
    "card_flipped",
    "timer_updated",
    "player_turn_changed",
    "hint_used",
    "heartbeat"
  ],

  # Event retention policy
  retention_policy: %{
    # Keep all events for 30 days
    default: :timer.hours(24 * 30),

    # Keep critical events indefinitely
    "game_started": :infinity,
    "game_ended": :infinity,
    "player_joined": :infinity,
    "player_left": :infinity,
    "team_eliminated": :infinity,

    # Keep high-frequency events for only 7 days
    "guess_made": :timer.hours(24 * 7),
    "card_flipped": :timer.hours(24 * 7),
    "timer_updated": :timer.hours(24 * 7),
    "player_turn_changed": :timer.hours(24 * 7),
    "hint_used": :timer.hours(24 * 7),
    "heartbeat": :timer.hours(24 * 7)
  },

  # Storage quotas
  storage_quotas: %{
    # Maximum storage per guild (in bytes)
    guild_max: 1_000_000_000,  # 1GB

    # Maximum storage per game (in bytes)
    game_max: 10_000_000,  # 10MB

    # Action when quota is reached
    quota_action: :aggregate_old_events  # Options: :aggregate_old_events, :delete_old_events, :notify_only
  }

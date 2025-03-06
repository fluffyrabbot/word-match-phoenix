# Test Fixes Checklist

## Critical (Blocking Test Execution)
- [ ] Fix test assertions in `test/game_bot/bot/listener_test.exs` that are comparing `:ok` with `:error`
  - The `handle_event/1` function is returning `:ok` when tests expect `:error`
  - Affected tests:
    - `test handle_event/1 with messages rejects empty messages`
    - `test handle_event/1 with messages enforces rate limiting`
    - `test handle_event/1 with messages detects spam messages`
    - `test error handling handles Nostrum API errors gracefully`
    - `test handle_event/1 with interactions rejects invalid interaction types`
    - `test handle_event/1 with interactions handles API errors in interaction responses`

## High Priority (EventStore Implementation)
- [ ] Fix conflicting behaviours in `GameBot.TestEventStore`
  - [ ] Resolve `init/1` conflict between `EventStore` and `GenServer`
  - [ ] Add missing required callbacks:
    - `config/0`
    - `subscribe/2`
    - `subscribe_to_stream/4`
    - `unsubscribe_from_all_streams/2`
    - `unsubscribe_from_stream/3`
  - [ ] Add missing `@impl true` annotations for:
    - `start_link/1`
    - `stop/2`
    - `ack/2`

## Medium Priority (Function Implementations)
- [ ] Implement missing functions in `GameBot.Domain.GameState`:
  - [ ] `new/2` (or update calls to use `new/3`)
  - [ ] `increment_guess_count/2` (or update calls to use `increment_guess_count/3`)

- [ ] Implement missing functions in `GameBot.Bot.Commands`:
  - [ ] `GameCommands.handle_guess/3` (or update calls to use `handle_guess/4`)
  - [ ] `StatsCommands.handle_command/2`
  - [ ] `ReplayCommands.handle_command/2`
  - [ ] `GameCommands.handle_command/2`

- [ ] Implement missing functions in `GameBot.Bot.Dispatcher`:
  - [ ] `handle_interaction/1`
  - [ ] `handle_message/1`

## Low Priority (Cleanup & Optimization)
- [ ] Fix deprecated Nostrum API calls
  - [ ] Replace `Api.create_message/2` with `Api.Message.create/2`

- [ ] Remove unused functions:
  - [ ] `maybe_notify_user/2` clauses in `GameBot.Bot.Listener`

- [ ] Fix undefined or private function warnings:
  - [ ] `GameBot.Infrastructure.EventStore.reset!/0`
  - [ ] `GameBot.Infrastructure.EventStore.stream_version/1`
  - [ ] `GameBot.Infrastructure.Persistence.Error.from_exception/2`
  - [ ] `EventStore.Config.parsed/1`
  - [ ] `EventStore.Tasks.Migrate.run/2`

## Documentation & Type Fixes
- [ ] Fix typing violations in test assertions
  - [ ] Update type specs to handle `:ok` vs `:error` comparisons properly

- [ ] Fix module documentation
  - [ ] Add proper `@moduledoc` strings
  - [ ] Document public API functions

## Notes
- Many of these issues are interconnected. For example, fixing the EventStore implementation might resolve some of the undefined function warnings.
- Some warnings might be false positives due to compile-time dependencies.
- Consider using dialyzer for more thorough type checking. 
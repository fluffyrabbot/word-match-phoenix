## SpecStory

## Optimizing listener_test.exs Execution Time (3/6/2025, 3:24:34 AM)

_**User**_

 we managed to pass the test, but @listener_test.exs is there any way to optimize this test to have it take less than 2 seconds?

---

_**Assistant**_

<think>
I need to analyze the `listener_test.exs` file to find opportunities for optimization. Currently, the test takes 2 seconds to run, and the user wants to reduce this time.

Looking at the test file, I can see that it's testing the `GameBot.Bot.Listener` module, which handles Discord events using Nostrum. The tests cover:
1. Handling interactions (INTERACTION_CREATE events)
2. Handling messages (MESSAGE_CREATE events)
3. Error handling for both types of events

Some potential optimization opportunities:

1. **Reduce setup/teardown overhead**: The setup function starts the Listener and NostrumApiMock for each test. This could potentially be optimized.

2. **Mocking strategy**: The test is using `Mock` library which uses runtime mocking. This is known to be slower than compile-time mocking alternatives.

3. **ETS table operations**: The tests create, delete, and manipulate ETS tables which could add overhead.

4. **Redundant mock setups**: Each test defines its own mocks, which could be consolidated.

5. **Unnecessary delays**: There might be unnecessary timeouts or sleeps in the Listener implementation that are slowing down the tests.

I'll need to examine these areas more closely to come up with specific optimization recommendations.
</think>

Looking at the `listener_test.exs` file, I can see some opportunities to optimize the test execution time. Currently, the tests are taking 2 seconds to run. Here are several approaches we can implement to make the tests run faster:

1. First, let's examine what's happening by looking at the test durations:

---

_****_

Read file: game_bot/lib/game_bot/bot/listener.ex

---

_****_

Let me look at the actual listener implementation to better understand what we're testing:

---

_****_

```bash
cd game_bot && mix test test/game_bot/bot/listener_test.exs --trace
```

```

      * EventStore.unsubscribe_from_stream/3 (function)

    │
 79 │   def stream_version(stream_id) do
    │   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:79: GameB
ot.Infrastructure.Persistenc
e.EventStore.Postgres (module)
                            
    warning: got "@impl EventStore" for function config/1 but this behaviour doe
s not specify such callback.
 The known callbacks are:
                            
      * EventStore.ack/2 (function)
      * EventStore.append_to_stream/4 (function)
      * EventStore.config/0 (function)
      * EventStore.delete_all_streams_subscription/2 (function)
      * EventStore.delete_snapshot/2 (function)
      * EventStore.delete_stream/4 (function)
      * EventStore.delete_subscription/3 (function)
      * EventStore.init/1 (function)
      * EventStore.link_to_stream/4 (function)
      * EventStore.paginate_streams/1 (function)
      * EventStore.read_all_streams_backward/3 (function)
      * EventStore.read_all_streams_forward/3 (function)
      * EventStore.read_snapshot/2 (function)
      * EventStore.read_stream_backward/4 (function)
      * EventStore.read_stream_forward/4 (function)
      * EventStore.record_snapshot/2 (function)
      * EventStore.start_link/1 (function)
      * EventStore.stop/2 (function)
      * EventStore.stream_all_backward/2 (function)
      * EventStore.stream_all_forward/2 (function)
      * EventStore.stream_backward/3 (function)
      * EventStore.stream_forward/3 (function)
      * EventStore.stream_info/2 (function)
      * EventStore.subscribe/2 (function)
      * EventStore.subscribe_to_all_streams/3 (function)
      * EventStore.subscribe_to_stream/4 (function)
      * EventStore.unsubscribe_from_all_streams/2 (function)
      * EventStore.unsubscribe_from_stream/3 (function)

    │
 88 │   def config(opts) do
    │   ~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:88: GameB
ot.Infrastructure.Persistenc
e.EventStore.Postgres (module)
                            
    warning: EventStore.ack/2 is undefined or private
    │
 99 │   def ack(subscription, events), do: EventStore.ack(subscription, events)
    │                                                 ~
    │
    └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:99:49: Ga
meBot.Infrastructure.Persist
ence.EventStore.Postgres.ack/2
                            
     warning: EventStore.delete_all_streams_subscription/2 is undefined or priva
te
     │
 103 │     do: EventStore.delete_all_streams_subscription(subscription_name, opt
s)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:103:20:
GameBot.Infrastructure.Persi
stence.EventStore.Postgres.delete_all_streams_subscription/2
                            
     warning: EventStore.delete_snapshot/2 is undefined or private
     │
 107 │     do: EventStore.delete_snapshot(source_uuid, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:107:20:
GameBot.Infrastructure.Persi
stence.EventStore.Postgres.delete_snapshot/2
                            
     warning: EventStore.delete_stream/4 is undefined or private
     │
 111 │     do: EventStore.delete_stream(stream_id, expected_version, hard_delete
, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:111:20:
GameBot.Infrastructure.Persi
stence.EventStore.Postgres.delete_stream/4
                            
     warning: EventStore.delete_subscription/3 is undefined or private
     │
 115 │     do: EventStore.delete_subscription(stream_id, subscription_name, opts
)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:115:20:
GameBot.Infrastructure.Persi
stence.EventStore.Postgres.delete_subscription/3
                            
     warning: EventStore.link_to_stream/4 is undefined or private
     │
 119 │     do: EventStore.link_to_stream(stream_id, expected_version, event_numb
ers, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:119:20:
GameBot.Infrastructure.Persi
stence.EventStore.Postgres.link_to_stream/4
                            
     warning: EventStore.paginate_streams/1 is undefined or private
     │
 123 │     do: EventStore.paginate_streams(opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:123:20:
GameBot.Infrastructure.Persi
stence.EventStore.Postgres.paginate_streams/1
                            
     warning: EventStore.read_all_streams_backward/3 is undefined or private
     │
 127 │     do: EventStore.read_all_streams_backward(start_from, count, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:127:20:
GameBot.Infrastructure.Persi
stence.EventStore.Postgres.read_all_streams_backward/3
                            
     warning: EventStore.read_all_streams_forward/3 is undefined or private
     │
 131 │     do: EventStore.read_all_streams_forward(start_from, count, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:131:20:
GameBot.Infrastructure.Persi
stence.EventStore.Postgres.read_all_streams_forward/3
                            
     warning: EventStore.read_snapshot/2 is undefined or private
     │
 135 │     do: EventStore.read_snapshot(source_uuid, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:135:20:
GameBot.Infrastructure.Persi
stence.EventStore.Postgres.read_snapshot/2
                            
     warning: EventStore.read_stream_backward/4 is undefined or private
     │
 139 │     do: EventStore.read_stream_backward(stream_id, start_version, count,
opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:139:20:
GameBot.Infrastructure.Persi
stence.EventStore.Postgres.read_stream_backward/4
                            
     warning: EventStore.record_snapshot/2 is undefined or private
     │
 143 │     do: EventStore.record_snapshot(snapshot, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:143:20:
GameBot.Infrastructure.Persi
stence.EventStore.Postgres.record_snapshot/2
                            
     warning: EventStore.start_link/1 is undefined or private
     │
 147 │     do: EventStore.start_link(opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:147:20:
GameBot.Infrastructure.Persi
stence.EventStore.Postgres.start_link/1
                            
     warning: EventStore.stop/2 is undefined or private
     │
 151 │     do: EventStore.stop(server, timeout)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:151:20:
GameBot.Infrastructure.Persi
stence.EventStore.Postgres.stop/2
                            
     warning: EventStore.stream_all_backward/2 is undefined or private
     │
 155 │     do: EventStore.stream_all_backward(start_from, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:155:20:
GameBot.Infrastructure.Persi
stence.EventStore.Postgres.stream_all_backward/2
                            
     warning: EventStore.stream_all_forward/2 is undefined or private
     │
 159 │     do: EventStore.stream_all_forward(start_from, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:159:20:
GameBot.Infrastructure.Persi
stence.EventStore.Postgres.stream_all_forward/2
                            
     warning: EventStore.stream_backward/3 is undefined or private
     │
 163 │     do: EventStore.stream_backward(stream_id, start_version, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:163:20:
GameBot.Infrastructure.Persi
stence.EventStore.Postgres.stream_backward/3
                            
     warning: EventStore.stream_forward/3 is undefined or private
     │
 167 │     do: EventStore.stream_forward(stream_id, start_version, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:167:20:
GameBot.Infrastructure.Persi
stence.EventStore.Postgres.stream_forward/3
                            
     warning: EventStore.stream_info/2 is undefined or private
     │
 171 │     do: EventStore.stream_info(stream_id, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:171:20:
GameBot.Infrastructure.Persi
stence.EventStore.Postgres.stream_info/2
                            
     warning: EventStore.subscribe/2 is undefined or private
     │
 175 │     do: EventStore.subscribe(subscriber, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:175:20:
GameBot.Infrastructure.Persi
stence.EventStore.Postgres.subscribe/2
                            
     warning: got "@impl EventStore" for function subscribe_to_all_streams/4 but
 this behaviour does not spe
cify such callback. The known callbacks are:
                            
       * EventStore.ack/2 (function)
       * EventStore.append_to_stream/4 (function)
       * EventStore.config/0 (function)
       * EventStore.delete_all_streams_subscription/2 (function)
       * EventStore.delete_snapshot/2 (function)
       * EventStore.delete_stream/4 (function)
       * EventStore.delete_subscription/3 (function)
       * EventStore.init/1 (function)
       * EventStore.link_to_stream/4 (function)
       * EventStore.paginate_streams/1 (function)
       * EventStore.read_all_streams_backward/3 (function)
       * EventStore.read_all_streams_forward/3 (function)
       * EventStore.read_snapshot/2 (function)
       * EventStore.read_stream_backward/4 (function)
       * EventStore.read_stream_forward/4 (function)
       * EventStore.record_snapshot/2 (function)
       * EventStore.start_link/1 (function)
       * EventStore.stop/2 (function)
       * EventStore.stream_all_backward/2 (function)
       * EventStore.stream_all_forward/2 (function)
       * EventStore.stream_backward/3 (function)
       * EventStore.stream_forward/3 (function)
       * EventStore.stream_info/2 (function)
       * EventStore.subscribe/2 (function)
       * EventStore.subscribe_to_all_streams/3 (function)
       * EventStore.subscribe_to_stream/4 (function)
       * EventStore.unsubscribe_from_all_streams/2 (function)
       * EventStore.unsubscribe_from_stream/3 (function)

     │
 178 │   def subscribe_to_all_streams(subscription_name, subscriber, subscriptio
n_options, opts),
     │   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:178: Gam
eBot.Infrastructure.Persiste
nce.EventStore.Postgres (module)
                            
     warning: EventStore.subscribe_to_all_streams/4 is undefined or private
     │
 179 │     do: EventStore.subscribe_to_all_streams(subscription_name, subscriber
, subscription_options, opts
)
                                 │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:179:20:
GameBot.Infrastructure.Persi
stence.EventStore.Postgres.subscribe_to_all_streams/4
                            
     warning: EventStore.unsubscribe_from_all_streams/2 is undefined or private
     │
 183 │     do: EventStore.unsubscribe_from_all_streams(subscription, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:183:20:
GameBot.Infrastructure.Persi
stence.EventStore.Postgres.unsubscribe_from_all_streams/2
                            
     warning: EventStore.unsubscribe_from_stream/3 is undefined or private
     │
 187 │     do: EventStore.unsubscribe_from_stream(stream_id, subscription, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:187:20:
GameBot.Infrastructure.Persi
stence.EventStore.Postgres.unsubscribe_from_stream/3
                            
     warning: EventStore.Stream.append_to_stream/3 is undefined (module EventSto
re.Stream is not available o
r is yet to be defined)
                                 │
 232 │       case Stream.append_to_stream(stream_id, expected_version, event_dat
a) do
     │                   ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:232:19:
GameBot.Infrastructure.Persi
stence.EventStore.Postgres.do_append/3
                            
     warning: EventStore.Stream.read_stream_forward/3 is undefined (module Event
Store.Stream is not availabl
e or is yet to be defined)
                                 │
 245 │       case Stream.read_stream_forward(stream_id, start_version, count) do
     │                   ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:245:19:
GameBot.Infrastructure.Persi
stence.EventStore.Postgres.do_read_forward/3
                            
     warning: EventStore.Stream.subscribe_to_stream/3 is undefined (module Event
Store.Stream is not availabl
e or is yet to be defined)
                                 │
 259 │       case Stream.subscribe_to_stream(stream_id, subscriber, options) do
     │                   ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:259:19:
GameBot.Infrastructure.Persi
stence.EventStore.Postgres.do_subscribe/3
                            
     warning: EventStore.Stream.stream_version/1 is undefined (module EventStore
.Stream is not available or 
is yet to be defined)
                                 │
 281 │       Stream.stream_version(stream_id)
     │              ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:281:14:
GameBot.Infrastructure.Persi
stence.EventStore.Postgres.do_get_version/1
                            
     warning: variable "reason" is unused (if the variable is not meant to be us
ed, prefix it with an unders
core)
                                 │
 288 │   defp maybe_notify_interaction_error({:error, reason}, _), do: :ok
     │                                                ~~~~~~
     │
     └─ lib/game_bot/bot/listener.ex:288:48: GameBot.Bot.Listener.maybe_notify_i
nteraction_error/2

     warning: function get_validation_type/1 is unused
     │
 326 │   defp get_validation_type(:rate_limited), do: :rate_limit
     │        ~
     │
     └─ lib/game_bot/bot/listener.ex:326:8: GameBot.Bot.Listener (module)

    warning: module attribute @max_mentions was set but never used
    │
 55 │   @max_mentions 5
    │   ~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/bot/listener.ex:55: GameBot.Bot.Listener (module)

    warning: module attribute @min_message_length was set but never used
    │
 54 │   @min_message_length 1
    │   ~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/bot/listener.ex:54: GameBot.Bot.Listener (module)

    warning: module attribute @max_message_length was set but never used
    │
 53 │   @max_message_length 2000
    │   ~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/bot/listener.ex:53: GameBot.Bot.Listener (module)

     warning: Nostrum.Api.create_message/2 is deprecated. Calling `Nostrum.Api`
functions directly will be r
emoved in v1.0
                                 Use `Nostrum.Api.Message.create/2` directly ins
tead.

     │
 248 │     case Api.create_message(channel_id, message) do
     │              ~
     │
     └─ lib/game_bot/bot/listener.ex:248:14: GameBot.Bot.Listener.maybe_notify_u
ser/2

     warning: Nostrum.Api.create_message/2 is deprecated. Calling `Nostrum.Api`
functions directly will be r
emoved in v1.0
                                 Use `Nostrum.Api.Message.create/2` directly ins
tead.

     │
 262 │     case Api.create_message(channel_id, message) do
     │              ~
     │
     └─ lib/game_bot/bot/listener.ex:262:14: GameBot.Bot.Listener.maybe_notify_u
ser/2

     warning: Nostrum.Api.create_message/2 is deprecated. Calling `Nostrum.Api`
functions directly will be r
emoved in v1.0
                                 Use `Nostrum.Api.Message.create/2` directly ins
tead.

     │
 275 │     case Api.create_message(channel_id, message) do
     │              ~
     │
     └─ lib/game_bot/bot/listener.ex:275:14: GameBot.Bot.Listener.maybe_notify_u
ser/2

     warning: this clause of defp maybe_notify_interaction_error/2 is never used
     │
 288 │   defp maybe_notify_interaction_error({:error, reason}, _), do: :ok
     │        ~
     │
     └─ lib/game_bot/bot/listener.ex:288:8: GameBot.Bot.Listener.maybe_notify_in
teraction_error/2

     warning: Nostrum.Api.create_interaction_response/3 is deprecated. Calling `
Nostrum.Api` functions direc
tly will be removed in v1.0
                                 Use `Nostrum.Api.Interaction.create_response/3`
 directly instead.

     │
 299 │     case Api.create_interaction_response(
     │              ~
     │
     └─ lib/game_bot/bot/listener.ex:299:14: GameBot.Bot.Listener.respond_with_e
rror/2

     warning: function with_retries/4 is unused
     │
 249 │   defp with_retries(operation, func, args, retry_count \\ 0) do
     │        ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/adapter.ex:249:8: Ga
meBot.Infrastructure.Persist
ence.EventStore.Adapter (module)
                            
     warning: function transform_error/6 is unused
     │
 146 │   defp transform_error(:append, error, stream_id, version, events, _opts)
 do
     │        ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/adapter.ex:146:8: Ga
meBot.Infrastructure.Persist
ence.EventStore.Adapter (module)
                            
     warning: function calculate_backoff/1 is unused
     │
 267 │   defp calculate_backoff(retry_count) do
     │        ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/adapter.ex:267:8: Ga
meBot.Infrastructure.Persist
ence.EventStore.Adapter (module)
                            
    warning: unused alias Behaviour
    │
 14 │   alias GameBot.Infrastructure.Persistence.EventStore.{Behaviour, Serializ
er}
    │   ~
    │
    └─ lib/game_bot/infrastructure/persistence/event_store/adapter.ex:14:3

     warning: GameBot.Infrastructure.Persistence.Error.from_exception/2 is undef
ined or private
     │
 260 │           error = Error.from_exception(e, __MODULE__)
     │                         ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/adapter.ex:260:25: G
ameBot.Infrastructure.Persis
tence.EventStore.Adapter.with_retries/4
                            
    warning: module attribute @base_fields was set but never used
    │
 40 │   @base_fields [:game_id, :mode, :round_number, :timestamp, :metadata]
    │   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/domain/events/game_events.ex:40: GameBot.Domain.Events.GameE
vents (module)

     warning: variable "result" is unused (if the variable is not meant to be us
ed, prefix it with an unders
core)
                                 │
 198 │       {:reply, {:round_end, _}, _} = result ->
     │                                      ~
     │
     └─ lib/game_bot/game_sessions/session.ex:198:38: GameBot.GameSessions.Sessi
on.handle_info/2

     warning: variable "state" is unused (if the variable is not meant to be use
d, prefix it with an undersc
ore)
                                 │
 363 │   defp validate_guild_context(word, player_id, %{guild_id: guild_id} = st
ate) do
     │                                                                        ~~
~~~
     │
     └─ lib/game_bot/game_sessions/session.ex:363:72: GameBot.GameSessions.Sessi
on.validate_guild_context/3 

     warning: variable "word" is unused (if the variable is not meant to be used
, prefix it with an undersco
re)
                                 │
 363 │   defp validate_guild_context(word, player_id, %{guild_id: guild_id} = st
ate) do
     │                               ~~~~
     │
     └─ lib/game_bot/game_sessions/session.ex:363:31: GameBot.GameSessions.Sessi
on.validate_guild_context/3 

     warning: variable "guild_id" is unused (if the variable is not meant to be
used, prefix it with an unde
rscore)
                                 │
 373 │   defp player_in_guild?(player_id, guild_id) do
     │                                    ~~~~~~~~
     │
     └─ lib/game_bot/game_sessions/session.ex:373:36: GameBot.GameSessions.Sessi
on.player_in_guild?/2       

     warning: variable "player_id" is unused (if the variable is not meant to be
 used, prefix it with an und
erscore)
                                 │
 373 │   defp player_in_guild?(player_id, guild_id) do
     │                         ~~~~~~~~~
     │
     └─ lib/game_bot/game_sessions/session.ex:373:25: GameBot.GameSessions.Sessi
on.player_in_guild?/2       

    warning: unused alias BaseMode
    │
  9 │   alias GameBot.Domain.GameModes.BaseMode
    │   ~
    │
    └─ lib/game_bot/game_sessions/session.ex:9:3

    warning: unused alias GameEvents
    │
 13 │   alias GameBot.Domain.Events.{
    │   ~
    │
    └─ lib/game_bot/game_sessions/session.ex:13:3

     warning: GameBot.Domain.Events.GameFinished.new/4 is undefined (module Game
Bot.Domain.Events.GameFinish
ed is not available or is yet to be defined)
                                 │
 166 │         game_finished = Events.GameFinished.new(
     │                                             ~
     │
     └─ lib/game_bot/game_sessions/session.ex:166:45: GameBot.GameSessions.Sessi
on.handle_call/3

    warning: clauses with the same name should be grouped together, "def handle_
event/1" was previously defi
ned (lib/game_bot/domain/projections/game_projection.ex:54)
                                │
 92 │   def handle_event(%RoundStarted{} = event) do
    │       ~
    │
    └─ lib/game_bot/domain/projections/game_projection.ex:92:7

     warning: clauses with the same name should be grouped together, "def handle
_event/2" was previously def
ined (lib/game_bot/domain/projections/game_projection.ex:72)
                                 │
 107 │   def handle_event(%RoundFinished{} = event, %{round: round}) do
     │       ~
     │
     └─ lib/game_bot/domain/projections/game_projection.ex:107:7

     warning: variable "game_id" is unused (if the variable is not meant to be u
sed, prefix it with an under
score)
                                 │
 122 │   def get_game(game_id, guild_id) do
     │                ~~~~~~~
     │
     └─ lib/game_bot/domain/projections/game_projection.ex:122:16: GameBot.Domai
n.Projections.GameProjection
.get_game/2
                            
     warning: variable "guild_id" is unused (if the variable is not meant to be
used, prefix it with an unde
rscore)
                                 │
 122 │   def get_game(game_id, guild_id) do
     │                         ~~~~~~~~
     │
     └─ lib/game_bot/domain/projections/game_projection.ex:122:25: GameBot.Domai
n.Projections.GameProjection
.get_game/2
                            
     warning: variable "guild_id" is unused (if the variable is not meant to be
used, prefix it with an unde
rscore)
                                 │
 128 │   def list_active_games(guild_id) do
     │                         ~~~~~~~~
     │
     └─ lib/game_bot/domain/projections/game_projection.ex:128:25: GameBot.Domai
n.Projections.GameProjection
.list_active_games/1
                            
     warning: variable "guild_id" is unused (if the variable is not meant to be
used, prefix it with an unde
rscore)
                                 │
 133 │   def list_recent_games(guild_id, limit \\ 10) do
     │                         ~~~~~~~~
     │
     └─ lib/game_bot/domain/projections/game_projection.ex:133:25: GameBot.Domai
n.Projections.GameProjection
.list_recent_games/2
                            
     warning: variable "limit" is unused (if the variable is not meant to be use
d, prefix it with an undersc
ore)
                                 │
 133 │   def list_recent_games(guild_id, limit \\ 10) do
     │                                   ~~~~~
     │
     └─ lib/game_bot/domain/projections/game_projection.ex:133:35: GameBot.Domai
n.Projections.GameProjection
.list_recent_games/2
                            
     warning: variable "guild_id" is unused (if the variable is not meant to be
used, prefix it with an unde
rscore)
                                 │
 138 │   def get_user_games(user_id, guild_id, limit \\ 10) do
     │                               ~~~~~~~~
     │
     └─ lib/game_bot/domain/projections/game_projection.ex:138:31: GameBot.Domai
n.Projections.GameProjection
.get_user_games/3
                            
     warning: variable "limit" is unused (if the variable is not meant to be use
d, prefix it with an undersc
ore)
                                 │
 138 │   def get_user_games(user_id, guild_id, limit \\ 10) do
     │                                         ~~~~~
     │
     └─ lib/game_bot/domain/projections/game_projection.ex:138:41: GameBot.Domai
n.Projections.GameProjection
.get_user_games/3
                            
     warning: variable "user_id" is unused (if the variable is not meant to be u
sed, prefix it with an under
score)
                                 │
 138 │   def get_user_games(user_id, guild_id, limit \\ 10) do
     │                      ~~~~~~~
     │
     └─ lib/game_bot/domain/projections/game_projection.ex:138:22: GameBot.Domai
n.Projections.GameProjection
.get_user_games/3
                            
     warning: variable "game_id" is unused (if the variable is not meant to be u
sed, prefix it with an under
score)
                                 │
 143 │   def get_game_rounds(game_id, guild_id) do
     │                       ~~~~~~~
     │
     └─ lib/game_bot/domain/projections/game_projection.ex:143:23: GameBot.Domai
n.Projections.GameProjection
.get_game_rounds/2
                            
     warning: variable "guild_id" is unused (if the variable is not meant to be
used, prefix it with an unde
rscore)
                                 │
 143 │   def get_game_rounds(game_id, guild_id) do
     │                                ~~~~~~~~
     │
     └─ lib/game_bot/domain/projections/game_projection.ex:143:32: GameBot.Domai
n.Projections.GameProjection
.get_game_rounds/2
                            
     warning: variable "guild_id" is unused (if the variable is not meant to be
used, prefix it with an unde
rscore)
                                 │
 148 │   def get_game_statistics(guild_id, time_range \\ nil) do
     │                           ~~~~~~~~
     │
     └─ lib/game_bot/domain/projections/game_projection.ex:148:27: GameBot.Domai
n.Projections.GameProjection
.get_game_statistics/2
                            
     warning: variable "time_range" is unused (if the variable is not meant to b
e used, prefix it with an un
derscore)
                                 │
 148 │   def get_game_statistics(guild_id, time_range \\ nil) do
     │                                     ~~~~~~~~~~
     │
     └─ lib/game_bot/domain/projections/game_projection.ex:148:37: GameBot.Domai
n.Projections.GameProjection
.get_game_statistics/2
                            
    warning: unknown key .config in expression:

        event.config

    the given type does not have the given key:

        dynamic(%GameBot.Domain.Events.GameEvents.GameCreated{
          created_at: term(),
          created_by: term(),
          game_id: term(),
          guild_id: term(),
          metadata: term(),
          mode: term(),
          team_ids: term(),
          timestamp: term()
        })

    where "event" was given the type:

        # type: dynamic(%GameBot.Domain.Events.GameEvents.GameCreated{})
        # from: lib/game_bot/domain/projections/game_projection.ex:54:35
        %GameBot.Domain.Events.GameEvents.GameCreated{} = event

    typing violation found at:
    │
 66 │       total_rounds: event.config[:rounds] || 1
    │                           ~~~~~~
    │
    └─ lib/game_bot/domain/projections/game_projection.ex:66:27: GameBot.Domain.
Projections.GameProjection.h
andle_event/1
                            
    warning: unknown key .finished_at in expression:

        event.finished_at

    the given type does not have the given key:

        dynamic(%GameBot.Domain.Events.GameEvents.GameFinished{
          final_score: term(),
          game_id: term(),
          guild_id: term(),
          metadata: term(),
          mode: term(),
          round_number: term(),
          timestamp: term(),
          winner_team_id: term()
        })

    where "event" was given the type:

        # type: dynamic(%GameBot.Domain.Events.GameEvents.GameFinished{})
        # from: lib/game_bot/domain/projections/game_projection.ex:81:36
        %GameBot.Domain.Events.GameEvents.GameFinished{} = event

    typing violation found at:
    │
 84 │       finished_at: event.finished_at,
    │                          ~~~~~~~~~~~
    │
    └─ lib/game_bot/domain/projections/game_projection.ex:84:26: GameBot.Domain.
Projections.GameProjection.h
andle_event/2
                            
    warning: unknown key .started_at in expression:

        event.started_at

    the given type does not have the given key:

        dynamic(%GameBot.Domain.Events.GameEvents.RoundStarted{
          game_id: term(),
          guild_id: term(),
          metadata: term(),
          mode: term(),
          round_number: term(),
          team_states: term(),
          timestamp: term()
        })

    where "event" was given the type:

        # type: dynamic(%GameBot.Domain.Events.GameEvents.RoundStarted{})
        # from: lib/game_bot/domain/projections/game_projection.ex:92:36
        %GameBot.Domain.Events.GameEvents.RoundStarted{} = event

    typing violation found at:
    │
 97 │       started_at: event.started_at,
    │                         ~~~~~~~~~~
    │
    └─ lib/game_bot/domain/projections/game_projection.ex:97:25: GameBot.Domain.
Projections.GameProjection.h
andle_event/1
                            
    warning: function handle_transaction_error/2 is unused
    │
 83 │   defp handle_transaction_error(error, guild_id) do
    │        ~
    │
    └─ lib/game_bot/infrastructure/persistence/repo/transaction.ex:83:8: GameBot
.Infrastructure.Persistence.
Repo.Transaction (module)
                            
    warning: EventStore.Config.parsed/1 is undefined or private. Did you mean:

          * parsed/2

    │
 48 │       config = EventStore.Config.parsed(Application.get_env(:game_bot, :ev
ent_store) || [])
    │                                  ~
    │
    └─ lib/tasks/migrate.ex:48:34: Mix.Tasks.GameBot.Migrate.run/1

    warning: EventStore.Tasks.Migrate.run/2 is undefined or private
    │
 51 │       EventStore.Tasks.Migrate.run(config, event_store_path)
    │                                ~
    │
    └─ lib/tasks/migrate.ex:51:32: Mix.Tasks.GameBot.Migrate.run/1

    warning: variable "filtered_options" is unused (if the variable is not meant
 to be used, prefix it with 
an underscore)
                                │
 48 │     filtered_options = Map.put(options, :guild_id, guild_id)
    │     ~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/bot/commands/replay_commands.ex:48:5: GameBot.Bot.Commands.R
eplayCommands.fetch_match_hi
story/2
                            
    warning: variable "guild_id" is unused (if the variable is not meant to be u
sed, prefix it with an under
score)
                                │
 52 │   defp fetch_game_summary(game_id, guild_id) do
    │                                    ~~~~~~~~
    │
    └─ lib/game_bot/bot/commands/replay_commands.ex:52:36: GameBot.Bot.Commands.
ReplayCommands.fetch_game_su
mmary/2
                            
    warning: variable "game_events" is unused (if the variable is not meant to b
e used, prefix it with an un
derscore)
                                │
 62 │   defp validate_permissions(user_id, game_events) do
    │                                      ~~~~~~~~~~~
    │
    └─ lib/game_bot/bot/commands/replay_commands.ex:62:38: GameBot.Bot.Commands.
ReplayCommands.validate_perm
issions/2
                            
    warning: variable "user_id" is unused (if the variable is not meant to be us
ed, prefix it with an unders
core)
                                │
 62 │   defp validate_permissions(user_id, game_events) do
    │                             ~~~~~~~
    │
    └─ lib/game_bot/bot/commands/replay_commands.ex:62:29: GameBot.Bot.Commands.
ReplayCommands.validate_perm
issions/2
                            
    warning: variable "game_events" is unused (if the variable is not meant to b
e used, prefix it with an un
derscore)
                                │
 67 │   defp format_replay(game_events) do
    │                      ~~~~~~~~~~~
    │
    └─ lib/game_bot/bot/commands/replay_commands.ex:67:22: GameBot.Bot.Commands.
ReplayCommands.format_replay
/1
                            
    warning: variable "matches" is unused (if the variable is not meant to be us
ed, prefix it with an unders
core)
                                │
 75 │   defp format_match_history(matches) do
    │                             ~~~~~~~
    │
    └─ lib/game_bot/bot/commands/replay_commands.ex:75:29: GameBot.Bot.Commands.
ReplayCommands.format_match_
history/1
                            
    warning: variable "game" is unused (if the variable is not meant to be used,
 prefix it with an underscor
e)
                                │
 83 │   defp format_game_summary(game) do
    │                            ~~~~
    │
    └─ lib/game_bot/bot/commands/replay_commands.ex:83:28: GameBot.Bot.Commands.
ReplayCommands.format_game_s
ummary/1
                            
    warning: EventStore.read_stream_forward/4 is undefined or private
    │
 44 │     EventStore.read_stream_forward(game_id, 0, 1000, opts)
    │                ~
    │
    └─ lib/game_bot/bot/commands/replay_commands.ex:44:16: GameBot.Bot.Commands.
ReplayCommands.fetch_game_ev
ents/2
                            
     warning: clauses with the same name and arity (number of arguments) should
be grouped together, "def ha
ndle_call/3" was previously defined (lib/game_bot/test_event_store.ex:147)
                                 │
 214 │   def handle_call({:unsubscribe, _stream_id, subscription}, _from, state)
 do
     │       ~
     │
     └─ lib/game_bot/test_event_store.ex:214:7

    warning: conflicting behaviours found. Callback function init/1 is defined b
y both EventStore and GenSer
ver (in module GameBot.TestEventStore)
                                │
  1 │ defmodule GameBot.TestEventStore do
    │ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/test_event_store.ex:1: GameBot.TestEventStore (module)

    warning: function config/0 required by behaviour EventStore is not implement
ed (in module GameBot.TestEv
entStore)
                                │
  1 │ defmodule GameBot.TestEventStore do
    │ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/test_event_store.ex:1: GameBot.TestEventStore (module)

    warning: function subscribe/2 required by behaviour EventStore is not implem
ented (in module GameBot.Tes
tEventStore)
                                │
  1 │ defmodule GameBot.TestEventStore do
    │ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/test_event_store.ex:1: GameBot.TestEventStore (module)

    warning: function subscribe_to_stream/4 required by behaviour EventStore is
not implemented (in module G
ameBot.TestEventStore)
                                │
  1 │ defmodule GameBot.TestEventStore do
    │ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/test_event_store.ex:1: GameBot.TestEventStore (module)

    warning: function unsubscribe_from_all_streams/2 required by behaviour Event
Store is not implemented (in
 module GameBot.TestEventStore)
                                │
  1 │ defmodule GameBot.TestEventStore do
    │ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/test_event_store.ex:1: GameBot.TestEventStore (module)

    warning: function unsubscribe_from_stream/3 required by behaviour EventStore
 is not implemented (in modu
le GameBot.TestEventStore)
                                │
  1 │ defmodule GameBot.TestEventStore do
    │ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/test_event_store.ex:1: GameBot.TestEventStore (module)

    warning: module attribute @impl was not set for function start_link/1 callba
ck (specified in EventStore)
. This either means you forgot to add the "@impl true" annotation before the def
inition or that you are accidentally overriding this callback
                                                            │
 19 │   def start_link(opts \\ []) do
    │   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/test_event_store.ex:19: GameBot.TestEventStore (module)

    warning: module attribute @impl was not set for function stop/2 callback (sp
ecified in EventStore). This
 either means you forgot to add the "@impl true" annotation before the definitio
n or that you are accidentally overriding this callback
                                                            │
 23 │   def stop(server, timeout \\ :infinity) do
    │   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/test_event_store.ex:23: GameBot.TestEventStore (module)

    warning: got "@impl EventStore" for function subscribe_to_stream/3 but this
behaviour does not specify s
uch callback. The known callbacks are:
                            
      * EventStore.subscribe/2 (function)
      * EventStore.stream_info/2 (function)
      * EventStore.delete_all_streams_subscription/2 (function)
      * EventStore.subscribe_to_stream/4 (function)
      * EventStore.record_snapshot/2 (function)
      * EventStore.delete_snapshot/2 (function)
      * EventStore.read_stream_backward/4 (function)
      * EventStore.stream_forward/3 (function)
      * EventStore.append_to_stream/4 (function)
      * EventStore.config/0 (function)
      * EventStore.start_link/1 (function)
      * EventStore.read_all_streams_backward/3 (function)
      * EventStore.read_snapshot/2 (function)
      * GenServer.code_change/3 (function)
      * EventStore.link_to_stream/4 (function)
      * GenServer.handle_info/2 (function)
      * EventStore.stop/2 (function)
      * EventStore.ack/2 (function)
      * EventStore.delete_stream/4 (function)
      * EventStore.subscribe_to_all_streams/3 (function)
      * GenServer.handle_call/3 (function)
      * EventStore.unsubscribe_from_stream/3 (function)
      * EventStore.unsubscribe_from_all_streams/2 (function)
      * EventStore.paginate_streams/1 (function)
      * GenServer.terminate/2 (function)
      * GenServer.format_status/2 (function)
      * GenServer.handle_cast/2 (function)
      * EventStore.stream_all_forward/2 (function)
      * GenServer.handle_continue/2 (function)
      * EventStore.read_all_streams_forward/3 (function)
      * EventStore.read_stream_forward/4 (function)
      * EventStore.stream_backward/3 (function)
      * EventStore.delete_subscription/3 (function)
      * EventStore.stream_all_backward/2 (function)
      * GenServer.init/1 (function)
      * EventStore.init/1 (function)
      * GenServer.format_status/1 (function)

    │
 60 │   def subscribe_to_stream(stream_id, subscriber, subscription_options \\ [
]) do
    │   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~
    │
    └─ lib/game_bot/test_event_store.ex:60: GameBot.TestEventStore (module)

    warning: got "@impl EventStore" for function unsubscribe_from_stream/2 but t
his behaviour does not speci
fy such callback. The known callbacks are:
                            
      * EventStore.subscribe/2 (function)
      * EventStore.stream_info/2 (function)
      * EventStore.delete_all_streams_subscription/2 (function)
      * EventStore.subscribe_to_stream/4 (function)
      * EventStore.record_snapshot/2 (function)
      * EventStore.delete_snapshot/2 (function)
      * EventStore.read_stream_backward/4 (function)
      * EventStore.stream_forward/3 (function)
      * EventStore.append_to_stream/4 (function)
      * EventStore.config/0 (function)
      * EventStore.start_link/1 (function)
      * EventStore.read_all_streams_backward/3 (function)
      * EventStore.read_snapshot/2 (function)
      * GenServer.code_change/3 (function)
      * EventStore.link_to_stream/4 (function)
      * GenServer.handle_info/2 (function)
      * EventStore.stop/2 (function)
      * EventStore.ack/2 (function)
      * EventStore.delete_stream/4 (function)
      * EventStore.subscribe_to_all_streams/3 (function)
      * GenServer.handle_call/3 (function)
      * EventStore.unsubscribe_from_stream/3 (function)
      * EventStore.unsubscribe_from_all_streams/2 (function)
      * EventStore.paginate_streams/1 (function)
      * GenServer.terminate/2 (function)
      * GenServer.format_status/2 (function)
      * GenServer.handle_cast/2 (function)
      * EventStore.stream_all_forward/2 (function)
      * GenServer.handle_continue/2 (function)
      * EventStore.read_all_streams_forward/3 (function)
      * EventStore.read_stream_forward/4 (function)
      * EventStore.stream_backward/3 (function)
      * EventStore.delete_subscription/3 (function)
      * EventStore.stream_all_backward/2 (function)
      * GenServer.init/1 (function)
      * EventStore.init/1 (function)
      * GenServer.format_status/1 (function)

    │
 75 │   def unsubscribe_from_stream(stream_id, subscription) do
    │   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/test_event_store.ex:75: GameBot.TestEventStore (module)

    warning: variable "state" is unused (if the variable is not meant to be used
, prefix it with an undersco
re)
                                │
 21 │   def execute(%State{} = state, %CreateTeamInvitation{} = cmd) do
    │                          ~~~~~
    │
    └─ lib/game_bot/domain/aggregates/team_aggregate.ex:21:26: GameBot.Domain.Ag
gregates.TeamAggregate.execu
te/2
                            
     warning: GameBot.Infrastructure.EventStore.stream_version/1 is undefined or
 private. Did you mean:     

           * stream_info/1
           * stream_info/2

     │
 104 │     case EventStore.stream_version(stream_id) do
     │                     ~
     │
     └─ lib/game_bot/infrastructure/event_store_adapter.ex:104:21: GameBot.Infra
structure.EventStoreAdapter.
validate_stream_size/1
                            
Running ExUnit with seed: 669288, max_cases: 1


GameBot.Bot.ListenerTest [test/game_bot/bot/listener_test.exs]
  * test handle_event/1 with interactions rejects invalid interaction types (207
.4ms) [L#52]
  * test handle_event/1 with interactions handles API errors in interaction resp
onses (228.5ms) [L#72]
  * test error handling handles Nostrum API errors gracefully (253.3ms) [L#183]
  * test handle_event/1 with messages rejects empty messages (170.5ms) [L#112]
  * test handle_event/1 with messages enforces rate limiting (172.4ms) [L#133]
  * test handle_event/1 with interactions accepts valid interaction types (244.2
ms) [L#35]
  * test handle_event/1 with messages accepts valid messages (243.7ms) [L#95]
  * test handle_event/1 with messages detects spam messages (169.4ms) [L#160]

Finished in 1.9 seconds (0.00s async, 1.9s sync)
8 tests, 0 failures

```

---

_****_

Let me check the code of the listener and the test file to understand how we can optimize it further:

---

_****_

Read file: game_bot/test/game_bot/bot/listener_test.exs

---

_****_

Now let's look at the NostrumApiMock implementation to better understand what could be optimized:

---

_****_

<details>
            <summary>Searched codebase "nostrum_api_mock" • **1** results</summary>
        
| File |
|------|
| `undefined` |

</details>

---

_****_

Read file: game_bot/test/support/mocks/nostrum_api_mock.ex

---

_****_

Based on the code review, here are several optimization strategies we can implement to make the `listener_test.exs` run faster:

---

_****_

```diff
    alias Nostrum.Struct.{Message, User, Interaction}
  
-   setup do
-     {:ok, _pid} = Listener.start_link()
- 
-     # Start NostrumApiMock
-     start_supervised!(NostrumApiMock)
- 
-     # Create rate limit table if it doesn't exist
+   # Shared fixtures to avoid recreating test data for each test
+   @valid_interaction %Interaction{
+     id: "123",
+     type: 2,
+     data: %{name: "test"},
+     token: "test_token",
+     channel_id: 123456
+   }
+ 
+   @invalid_interaction %Interaction{
+     id: "123",
+     type: 99,
+     data: %{name: "test"},
+     token: "test_token",
+     channel_id: 123456
+   }
+ 
+   @valid_message %Message{
+     id: "123",
+     content: "test message",
+     author: %User{id: "user1", bot: false},
+     channel_id: 123456,
+     mentions: []
+   }
+ 
+   @empty_message %Message{
+     id: "123",
+     content: "",
+     author: %User{id: "user1", bot: false},
+     channel_id: 123456,
+     mentions: []
+   }
+ 
+   # Use setup_all for one-time setup that can be shared across all tests
+   setup_all do
+     # Create the ETS table only once for all tests
      if :ets.whereis(:rate_limit) == :undefined do
        :ets.new(:rate_limit, [:named_table, :set, :public])
      end
-     :ets.delete_all_objects(:rate_limit)
- 
-     # Reset error simulation
-     NostrumApiMock.simulate_error(false)
  
      on_exit(fn ->
      :ok
    end
+ 
+   setup do
+     # Start the Listener only once if not already started
+     if Process.whereis(Listener) == nil do
+       {:ok, _pid} = Listener.start_link()
+     end
+ 
+     # Start NostrumApiMock
+     start_supervised!(NostrumApiMock)
+ 
+     # Clear rate limit table before each test
+     :ets.delete_all_objects(:rate_limit)
+ 
+     # Reset error simulation
+     NostrumApiMock.simulate_error(false)
+ 
+     :ok
+   end
+ 
+   # Define common mocks to reduce duplication
+   defp with_success_api_mock(test_func) do
+     mocks = [
+       {Nostrum.Api, [], [
+         create_interaction_response: fn _, _, _ -> {:ok, %{}} end,
+         create_message: fn _, _ -> {:ok, %{}} end
+       ]},
+       {GameBot.Bot.Dispatcher, [], [
+         handle_interaction: fn _ -> :ok end,
+         handle_message: fn _ -> :ok end
+       ]}
+     ]
+ 
+     with_mocks(mocks, do: test_func.())
+   end
+ 
+   defp with_error_api_mock(test_func) do
+     mocks = [
+       {Nostrum.Api, [], [
+         create_interaction_response: fn _, _, _ -> {:error, %{}} end,
+         create_message: fn _, _ -> {:error, %{}} end
+       ]},
+       {GameBot.Bot.Dispatcher, [], [
+         handle_interaction: fn _ -> {:error, :dispatcher_error} end,
+         handle_message: fn _ -> {:error, :dispatcher_error} end
+       ]}
+     ]
+ 
+     with_mocks(mocks, do: test_func.())
+   end
  
    describe "handle_event/1 with interactions" do
      test "accepts valid interaction types" do
-       interaction = %Interaction{
-         id: "123",
-         type: 2,
-         data: %{name: "test"},
-         token: "test_token",
-         channel_id: 123456
-       }
- 
-       with_mocks([
-         {Nostrum.Api, [], [create_interaction_response: fn _, _, _ -> {:ok, %{}} end]},
-         {GameBot.Bot.Dispatcher, [], [handle_interaction: fn _ -> :ok end]}
-       ]) do
-         assert Listener.handle_event({:INTERACTION_CREATE, interaction, nil}) == :ok
-       end
+       with_success_api_mock(fn ->
+         assert Listener.handle_event({:INTERACTION_CREATE, @valid_interaction, nil}) == :ok
+       end)
      end
  
      test "rejects invalid interaction types" do
-       interaction = %Interaction{
-         id: "123",
-         type: 99,
-         data: %{name: "test"},
-         token: "test_token",
-         channel_id: 123456
-       }
- 
        with_mocks([
          {Nostrum.Api, [], [create_interaction_response: fn _, _, _ -> {:ok, %{}} end]}
        ]) do
          log = capture_log(fn ->
-           assert Listener.handle_event({:INTERACTION_CREATE, interaction, nil}) == :error
+           assert Listener.handle_event({:INTERACTION_CREATE, @invalid_interaction, nil}) == :error
          end)
  
  
      test "handles API errors in interaction responses" do
-       interaction = %Interaction{
-         id: "123",
-         type: 2,
-         data: %{name: "test"},
-         token: "test_token",
-         channel_id: 123456
-       }
- 
-       with_mocks([
-         {Nostrum.Api, [], [create_interaction_response: fn _, _, _ -> {:error, %{}} end]},
-         {GameBot.Bot.Dispatcher, [], [handle_interaction: fn _ -> {:error, :dispatcher_error} end]}
-       ]) do
+       with_error_api_mock(fn ->
          log = capture_log(fn ->
-           assert Listener.handle_event({:INTERACTION_CREATE, interaction, nil}) == :error
+           assert Listener.handle_event({:INTERACTION_CREATE, @valid_interaction, nil}) == :error
          end)
  
          assert log =~ "Failed to send interaction error response"
-       end
+       end)
      end
    end
  
    describe "handle_event/1 with messages" do
      test "accepts valid messages" do
-       msg = %Message{
-         id: "123",
-         content: "test message",
-         author: %User{id: "user1", bot: false},
-         channel_id: 123456,
-         mentions: []
-       }
- 
-       with_mocks([
-         {Nostrum.Api, [], [create_message: fn _, _ -> {:ok, %{}} end]},
-         {GameBot.Bot.Dispatcher, [], [handle_message: fn _ -> :ok end]}
-       ]) do
-         assert Listener.handle_event({:MESSAGE_CREATE, msg, nil}) == :ok
-       end
+       with_success_api_mock(fn ->
+         assert Listener.handle_event({:MESSAGE_CREATE, @valid_message, nil}) == :ok
+       end)
      end
  
      test "rejects empty messages" do
-       msg = %Message{
-         id: "123",
-         content: "",
-         author: %User{id: "user1", bot: false},
-         channel_id: 123456,
-         mentions: []
-       }
- 
        with_mocks([
          {Nostrum.Api, [], [create_message: fn _, _ -> {:ok, %{}} end]}
        ]) do
          log = capture_log(fn ->
-           assert Listener.handle_event({:MESSAGE_CREATE, msg, nil}) == :error
+           assert Listener.handle_event({:MESSAGE_CREATE, @empty_message, nil}) == :error
          end)
  
  
      test "enforces rate limiting" do
-       msg = %Message{
-         id: "123",
-         content: "test message",
-         author: %User{id: "user1", bot: false},
-         channel_id: 123456,
-         mentions: []
-       }
- 
        # Simulate rate limit by adding timestamps
        now = System.system_time(:second)
-       # Create many timestamps to exceed the limit
-       timestamps = for i <- 1..31, do: now - i
+       # Create many timestamps to exceed the limit (more efficiently)
+       timestamps = List.duplicate(now - 1, 31)
        :ets.insert(:rate_limit, {"user1", timestamps})
  
        ]) do
          log = capture_log(fn ->
-           assert Listener.handle_event({:MESSAGE_CREATE, msg, nil}) == :error
+           assert Listener.handle_event({:MESSAGE_CREATE, @valid_message, nil}) == :error
          end)
  
  
      test "detects spam messages" do
-       msg = %Message{
-         id: "123",
-         content: String.duplicate("a", 2000),
-         author: %User{id: "user1", bot: false},
-         channel_id: 123456,
-         mentions: []
-       }
+       spam_message = %{@valid_message | content: String.duplicate("a", 2000)}
  
        with_mocks([
          {Nostrum.Api, [], [create_message: fn _, _ -> {:ok, %{}} end]}
        ]) do
          log = capture_log(fn ->
-           assert Listener.handle_event({:MESSAGE_CREATE, msg, nil}) == :error
+           assert Listener.handle_event({:MESSAGE_CREATE, spam_message, nil}) == :error
          end)
  
    describe "error handling" do
      test "handles Nostrum API errors gracefully" do
-       msg = %Message{
-         id: "123",
-         content: "test message",
-         author: %User{id: "user1", bot: false},
-         channel_id: 123456,
-         mentions: []
-       }
- 
-       with_mocks([
-         {Nostrum.Api, [], [create_message: fn _, _ -> {:error, %{}} end]},
-         {GameBot.Bot.Dispatcher, [], [handle_message: fn _ -> {:error, :dispatcher_error} end]}
-       ]) do
+       with_error_api_mock(fn ->
          log = capture_log(fn ->
-           assert Listener.handle_event({:MESSAGE_CREATE, msg, nil}) == :error
+           assert Listener.handle_event({:MESSAGE_CREATE, @valid_message, nil}) == :error
          end)
  
          assert log =~ "Failed to send message"
-       end
+       end)
      end
    end
```

---

_****_

Let's run the tests again to measure the performance improvement:

---

_****_

```bash
cd game_bot && mix test test/game_bot/bot/listener_test.exs --trace
```

```
$ cd game_bot && mix test test/game_bot/bot/listener_test.exs --trace

```

---

_****_

Let's try again:

---

_****_

```bash
cd game_bot && mix test test/game_bot/bot/listener_test.exs
```

---

_****_

Seems like there might be an issue with the test. Let's check if there's an error:

---

_****_

```bash
cd game_bot && mix compile
```

```
$ cd game_bot && mix compile

```

---

_****_

Let's try to identify the issue with the test:

---

_****_

```bash
cd game_bot && cat test/game_bot/bot/listener_test.exs
```

```
$ cd game_bot && cat test/game_bot/bot/listener_test.exs

```

---

_****_

Let's try to locate our test file:

---

_****_

```bash
cd game_bot && find . -name "listener_test.exs"
```

```
$ cd game_bot && find . -name "listener_test.exs"

```

---

_****_

Let's make sure we're in the correct directory and check the test directory:

---

_****_

```bash
ls -la
```

```
total 89
drwxr-xr-x 1 ktw30 197609     0 Mar  6 00:34 ./
drwxr-xr-x 1 ktw30 197609     0 Mar  6 03:25 ../
-rw-r--r-- 1 ktw30 197609   225 Mar  3 23:53 .formatter.exs
-rw-r--r-- 1 ktw30 197609   683 Mar  3 23:52 .gitattributes
-rw-r--r-- 1 ktw30 197609   629 Mar  3 23:52 .gitignore
drwxr-xr-x 1 ktw30 197609     0 Mar  4 02:16 _build/
drwxr-xr-x 1 ktw30 197609     0 Mar  4 02:16 config/
drwxr-xr-x 1 ktw30 197609     0 Mar  6 03:19 deps/
drwxr-xr-x 1 ktw30 197609     0 Mar  6 00:38 docs/
drwxr-xr-x 1 ktw30 197609     0 Mar  5 23:33 lib/
-rw-r--r-- 1 ktw30 197609  2990 Mar  6 03:18 mix.exs
-rw-r--r-- 1 ktw30 197609 25296 Mar  6 03:19 mix.lock
drwxr-xr-x 1 ktw30 197609     0 Mar  5 01:36 priv/
-rw-r--r-- 1 ktw30 197609 15458 Mar  4 17:02 README.md

```

---

_****_

Let's check the test directory:

---

_****_

```bash
ls -la test
```

```
$ ls -la test
total 20
drwxr-xr-x 1 ktw30 197609    0 Mar  4 06:58 ./
drwxr-xr-x 1 ktw30 197609    0 Mar  6 00:34 ../
drwxr-xr-x 1 ktw30 197609    0 Mar  3 22:01 bot/
drwxr-xr-x 1 ktw30 197609    0 Mar  3 23:53 domain/
drwxr-xr-x 1 ktw30 197609    0 Mar  5 23:32 game_bot/
drwxr-xr-x 1 ktw30 197609    0 Mar  3 21:57 game_bot_web/
drwxr-xr-x 1 ktw30 197609    0 Mar  3 23:53 game_sessions/
drwxr-xr-x 1 ktw30 197609    0 Mar  3 22:58 infrastructure/
drwxr-xr-x 1 ktw30 197609    0 Mar  6 00:58 support/
-rw-r--r-- 1 ktw30 197609 1094 Mar  6 02:48 test_helper.exs

```

---

_****_

Let's check the structure of the game_bot directory in the test folder:

---

_****_

```bash
find test/game_bot -type f | grep -i listener
```

```
$ find test/game_bot -type f | grep -i listener

```

---

_****_

Let's check the bot directory:

---

_****_

```bash
find test -name "listener_test.exs"
```

```
$ find test -name "listener_test.exs"

```

---

_****_

Let's check which tests are actually runnable:

---

_****_

```bash
mix test --list
```

```

      * EventStore.read_stream_forward/4 (function)
      * EventStore.record_snapshot/2 (function)
      * EventStore.start_link/1 (function)
      * EventStore.stop/2 (function)
      * EventStore.stream_all_backward/2 (function)
      * EventStore.stream_all_forward/2 (function)
      * EventStore.stream_backward/3 (function)
      * EventStore.stream_forward/3 (function)
      * EventStore.stream_info/2 (function)
      * EventStore.subscribe/2 (function)
      * EventStore.subscribe_to_all_streams/3 (function)
      * EventStore.subscribe_to_stream/4 (function)
      * EventStore.unsubscribe_from_all_streams/2 (function)
      * EventStore.unsubscribe_from_stream/3 (function)

    │
 79 │   def stream_version(stream_id) do
    │   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:79: GameBot.Infrastructure.Persistenc
e.EventStore.Postgres (module)

    warning: got "@impl EventStore" for function config/1 but this behaviour does not specify such callback.
 The known callbacks are:

      * EventStore.ack/2 (function)
      * EventStore.append_to_stream/4 (function)
      * EventStore.config/0 (function)
      * EventStore.delete_all_streams_subscription/2 (function)
      * EventStore.delete_snapshot/2 (function)
      * EventStore.delete_stream/4 (function)
      * EventStore.delete_subscription/3 (function)
      * EventStore.init/1 (function)
      * EventStore.link_to_stream/4 (function)
      * EventStore.paginate_streams/1 (function)
      * EventStore.read_all_streams_backward/3 (function)
      * EventStore.read_all_streams_forward/3 (function)
      * EventStore.read_snapshot/2 (function)
      * EventStore.read_stream_backward/4 (function)
      * EventStore.read_stream_forward/4 (function)
      * EventStore.record_snapshot/2 (function)
      * EventStore.start_link/1 (function)
      * EventStore.stop/2 (function)
      * EventStore.stream_all_backward/2 (function)
      * EventStore.stream_all_forward/2 (function)
      * EventStore.stream_backward/3 (function)
      * EventStore.stream_forward/3 (function)
      * EventStore.stream_info/2 (function)
      * EventStore.subscribe/2 (function)
      * EventStore.subscribe_to_all_streams/3 (function)
      * EventStore.subscribe_to_stream/4 (function)
      * EventStore.unsubscribe_from_all_streams/2 (function)
      * EventStore.unsubscribe_from_stream/3 (function)

    │
 88 │   def config(opts) do
    │   ~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:88: GameBot.Infrastructure.Persistenc
e.EventStore.Postgres (module)

    warning: EventStore.ack/2 is undefined or private
    │
 99 │   def ack(subscription, events), do: EventStore.ack(subscription, events)
    │                                                 ~
    │
    └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:99:49: GameBot.Infrastructure.Persist
ence.EventStore.Postgres.ack/2

     warning: EventStore.delete_all_streams_subscription/2 is undefined or private
     │
 103 │     do: EventStore.delete_all_streams_subscription(subscription_name, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:103:20: GameBot.Infrastructure.Persi
stence.EventStore.Postgres.delete_all_streams_subscription/2

     warning: EventStore.delete_snapshot/2 is undefined or private
     │
 107 │     do: EventStore.delete_snapshot(source_uuid, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:107:20: GameBot.Infrastructure.Persi
stence.EventStore.Postgres.delete_snapshot/2

     warning: EventStore.delete_stream/4 is undefined or private
     │
 111 │     do: EventStore.delete_stream(stream_id, expected_version, hard_delete, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:111:20: GameBot.Infrastructure.Persi
stence.EventStore.Postgres.delete_stream/4

     warning: EventStore.delete_subscription/3 is undefined or private
     │
 115 │     do: EventStore.delete_subscription(stream_id, subscription_name, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:115:20: GameBot.Infrastructure.Persi
stence.EventStore.Postgres.delete_subscription/3

     warning: EventStore.link_to_stream/4 is undefined or private
     │
 119 │     do: EventStore.link_to_stream(stream_id, expected_version, event_numbers, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:119:20: GameBot.Infrastructure.Persi
stence.EventStore.Postgres.link_to_stream/4

     warning: EventStore.paginate_streams/1 is undefined or private
     │
 123 │     do: EventStore.paginate_streams(opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:123:20: GameBot.Infrastructure.Persi
stence.EventStore.Postgres.paginate_streams/1

     warning: EventStore.read_all_streams_backward/3 is undefined or private
     │
 127 │     do: EventStore.read_all_streams_backward(start_from, count, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:127:20: GameBot.Infrastructure.Persi
stence.EventStore.Postgres.read_all_streams_backward/3

     warning: EventStore.read_all_streams_forward/3 is undefined or private
     │
 131 │     do: EventStore.read_all_streams_forward(start_from, count, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:131:20: GameBot.Infrastructure.Persi
stence.EventStore.Postgres.read_all_streams_forward/3

     warning: EventStore.read_snapshot/2 is undefined or private
     │
 135 │     do: EventStore.read_snapshot(source_uuid, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:135:20: GameBot.Infrastructure.Persi
stence.EventStore.Postgres.read_snapshot/2

     warning: EventStore.read_stream_backward/4 is undefined or private
     │
 139 │     do: EventStore.read_stream_backward(stream_id, start_version, count, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:139:20: GameBot.Infrastructure.Persi
stence.EventStore.Postgres.read_stream_backward/4

     warning: EventStore.record_snapshot/2 is undefined or private
     │
 143 │     do: EventStore.record_snapshot(snapshot, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:143:20: GameBot.Infrastructure.Persi
stence.EventStore.Postgres.record_snapshot/2

     warning: EventStore.start_link/1 is undefined or private
     │
 147 │     do: EventStore.start_link(opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:147:20: GameBot.Infrastructure.Persi
stence.EventStore.Postgres.start_link/1

     warning: EventStore.stop/2 is undefined or private
     │
 151 │     do: EventStore.stop(server, timeout)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:151:20: GameBot.Infrastructure.Persi
stence.EventStore.Postgres.stop/2

     warning: EventStore.stream_all_backward/2 is undefined or private
     │
 155 │     do: EventStore.stream_all_backward(start_from, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:155:20: GameBot.Infrastructure.Persi
stence.EventStore.Postgres.stream_all_backward/2

     warning: EventStore.stream_all_forward/2 is undefined or private
     │
 159 │     do: EventStore.stream_all_forward(start_from, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:159:20: GameBot.Infrastructure.Persi
stence.EventStore.Postgres.stream_all_forward/2

     warning: EventStore.stream_backward/3 is undefined or private
     │
 163 │     do: EventStore.stream_backward(stream_id, start_version, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:163:20: GameBot.Infrastructure.Persi
stence.EventStore.Postgres.stream_backward/3

     warning: EventStore.stream_forward/3 is undefined or private
     │
 167 │     do: EventStore.stream_forward(stream_id, start_version, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:167:20: GameBot.Infrastructure.Persi
stence.EventStore.Postgres.stream_forward/3

     warning: EventStore.stream_info/2 is undefined or private
     │
 171 │     do: EventStore.stream_info(stream_id, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:171:20: GameBot.Infrastructure.Persi
stence.EventStore.Postgres.stream_info/2

     warning: EventStore.subscribe/2 is undefined or private
     │
 175 │     do: EventStore.subscribe(subscriber, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:175:20: GameBot.Infrastructure.Persi
stence.EventStore.Postgres.subscribe/2

     warning: got "@impl EventStore" for function subscribe_to_all_streams/4 but this behaviour does not spe
cify such callback. The known callbacks are:

       * EventStore.ack/2 (function)
       * EventStore.append_to_stream/4 (function)
       * EventStore.config/0 (function)
       * EventStore.delete_all_streams_subscription/2 (function)
       * EventStore.delete_snapshot/2 (function)
       * EventStore.delete_stream/4 (function)
       * EventStore.delete_subscription/3 (function)
       * EventStore.init/1 (function)
       * EventStore.link_to_stream/4 (function)
       * EventStore.paginate_streams/1 (function)
       * EventStore.read_all_streams_backward/3 (function)
       * EventStore.read_all_streams_forward/3 (function)
       * EventStore.read_snapshot/2 (function)
       * EventStore.read_stream_backward/4 (function)
       * EventStore.read_stream_forward/4 (function)
       * EventStore.record_snapshot/2 (function)
       * EventStore.start_link/1 (function)
       * EventStore.stop/2 (function)
       * EventStore.stream_all_backward/2 (function)
       * EventStore.stream_all_forward/2 (function)
       * EventStore.stream_backward/3 (function)
       * EventStore.stream_forward/3 (function)
       * EventStore.stream_info/2 (function)
       * EventStore.subscribe/2 (function)
       * EventStore.subscribe_to_all_streams/3 (function)
       * EventStore.subscribe_to_stream/4 (function)
       * EventStore.unsubscribe_from_all_streams/2 (function)
       * EventStore.unsubscribe_from_stream/3 (function)

     │
 178 │   def subscribe_to_all_streams(subscription_name, subscriber, subscription_options, opts),
     │   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:178: GameBot.Infrastructure.Persiste
nce.EventStore.Postgres (module)

     warning: EventStore.subscribe_to_all_streams/4 is undefined or private
     │
 179 │     do: EventStore.subscribe_to_all_streams(subscription_name, subscriber, subscription_options, opts
)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:179:20: GameBot.Infrastructure.Persi
stence.EventStore.Postgres.subscribe_to_all_streams/4

     warning: EventStore.unsubscribe_from_all_streams/2 is undefined or private
     │
 183 │     do: EventStore.unsubscribe_from_all_streams(subscription, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:183:20: GameBot.Infrastructure.Persi
stence.EventStore.Postgres.unsubscribe_from_all_streams/2

     warning: EventStore.unsubscribe_from_stream/3 is undefined or private
     │
 187 │     do: EventStore.unsubscribe_from_stream(stream_id, subscription, opts)
     │                    ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:187:20: GameBot.Infrastructure.Persi
stence.EventStore.Postgres.unsubscribe_from_stream/3

     warning: EventStore.Stream.append_to_stream/3 is undefined (module EventStore.Stream is not available o
r is yet to be defined)
     │
 232 │       case Stream.append_to_stream(stream_id, expected_version, event_data) do
     │                   ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:232:19: GameBot.Infrastructure.Persi
stence.EventStore.Postgres.do_append/3

     warning: EventStore.Stream.read_stream_forward/3 is undefined (module EventStore.Stream is not availabl
e or is yet to be defined)
     │
 245 │       case Stream.read_stream_forward(stream_id, start_version, count) do
     │                   ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:245:19: GameBot.Infrastructure.Persi
stence.EventStore.Postgres.do_read_forward/3

     warning: EventStore.Stream.subscribe_to_stream/3 is undefined (module EventStore.Stream is not availabl
e or is yet to be defined)
     │
 259 │       case Stream.subscribe_to_stream(stream_id, subscriber, options) do
     │                   ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:259:19: GameBot.Infrastructure.Persi
stence.EventStore.Postgres.do_subscribe/3

     warning: EventStore.Stream.stream_version/1 is undefined (module EventStore.Stream is not available or 
is yet to be defined)
     │
 281 │       Stream.stream_version(stream_id)
     │              ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/postgres.ex:281:14: GameBot.Infrastructure.Persi
stence.EventStore.Postgres.do_get_version/1

     warning: variable "reason" is unused (if the variable is not meant to be used, prefix it with an unders
core)
     │
 288 │   defp maybe_notify_interaction_error({:error, reason}, _), do: :ok
     │                                                ~~~~~~
     │
     └─ lib/game_bot/bot/listener.ex:288:48: GameBot.Bot.Listener.maybe_notify_interaction_error/2

     warning: function get_validation_type/1 is unused
     │
 326 │   defp get_validation_type(:rate_limited), do: :rate_limit
     │        ~
     │
     └─ lib/game_bot/bot/listener.ex:326:8: GameBot.Bot.Listener (module)

    warning: module attribute @max_mentions was set but never used
    │
 55 │   @max_mentions 5
    │   ~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/bot/listener.ex:55: GameBot.Bot.Listener (module)

    warning: module attribute @min_message_length was set but never used
    │
 54 │   @min_message_length 1
    │   ~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/bot/listener.ex:54: GameBot.Bot.Listener (module)

    warning: module attribute @max_message_length was set but never used
    │
 53 │   @max_message_length 2000
    │   ~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/bot/listener.ex:53: GameBot.Bot.Listener (module)

     warning: Nostrum.Api.create_message/2 is deprecated. Calling `Nostrum.Api` functions directly will be r
emoved in v1.0
     Use `Nostrum.Api.Message.create/2` directly instead.

     │
 248 │     case Api.create_message(channel_id, message) do
     │              ~
     │
     └─ lib/game_bot/bot/listener.ex:248:14: GameBot.Bot.Listener.maybe_notify_user/2

     warning: Nostrum.Api.create_message/2 is deprecated. Calling `Nostrum.Api` functions directly will be r
emoved in v1.0
     Use `Nostrum.Api.Message.create/2` directly instead.

     │
 262 │     case Api.create_message(channel_id, message) do
     │              ~
     │
     └─ lib/game_bot/bot/listener.ex:262:14: GameBot.Bot.Listener.maybe_notify_user/2

     warning: Nostrum.Api.create_message/2 is deprecated. Calling `Nostrum.Api` functions directly will be r
emoved in v1.0
     Use `Nostrum.Api.Message.create/2` directly instead.

     │
 275 │     case Api.create_message(channel_id, message) do
     │              ~
     │
     └─ lib/game_bot/bot/listener.ex:275:14: GameBot.Bot.Listener.maybe_notify_user/2

     warning: this clause of defp maybe_notify_interaction_error/2 is never used
     │
 288 │   defp maybe_notify_interaction_error({:error, reason}, _), do: :ok
     │        ~
     │
     └─ lib/game_bot/bot/listener.ex:288:8: GameBot.Bot.Listener.maybe_notify_interaction_error/2

     warning: Nostrum.Api.create_interaction_response/3 is deprecated. Calling `Nostrum.Api` functions direc
tly will be removed in v1.0
     Use `Nostrum.Api.Interaction.create_response/3` directly instead.

     │
 299 │     case Api.create_interaction_response(
     │              ~
     │
     └─ lib/game_bot/bot/listener.ex:299:14: GameBot.Bot.Listener.respond_with_error/2

     warning: function with_retries/4 is unused
     │
 249 │   defp with_retries(operation, func, args, retry_count \\ 0) do
     │        ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/adapter.ex:249:8: GameBot.Infrastructure.Persist
ence.EventStore.Adapter (module)

     warning: function transform_error/6 is unused
     │
 146 │   defp transform_error(:append, error, stream_id, version, events, _opts) do
     │        ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/adapter.ex:146:8: GameBot.Infrastructure.Persist
ence.EventStore.Adapter (module)

     warning: function calculate_backoff/1 is unused
     │
 267 │   defp calculate_backoff(retry_count) do
     │        ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/adapter.ex:267:8: GameBot.Infrastructure.Persist
ence.EventStore.Adapter (module)

    warning: unused alias Behaviour
    │
 14 │   alias GameBot.Infrastructure.Persistence.EventStore.{Behaviour, Serializer}
    │   ~
    │
    └─ lib/game_bot/infrastructure/persistence/event_store/adapter.ex:14:3

     warning: GameBot.Infrastructure.Persistence.Error.from_exception/2 is undefined or private
     │
 260 │           error = Error.from_exception(e, __MODULE__)
     │                         ~
     │
     └─ lib/game_bot/infrastructure/persistence/event_store/adapter.ex:260:25: GameBot.Infrastructure.Persis
tence.EventStore.Adapter.with_retries/4

    warning: module attribute @base_fields was set but never used
    │
 40 │   @base_fields [:game_id, :mode, :round_number, :timestamp, :metadata]
    │   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/domain/events/game_events.ex:40: GameBot.Domain.Events.GameEvents (module)

     warning: variable "result" is unused (if the variable is not meant to be used, prefix it with an unders
core)
     │
 198 │       {:reply, {:round_end, _}, _} = result ->
     │                                      ~
     │
     └─ lib/game_bot/game_sessions/session.ex:198:38: GameBot.GameSessions.Session.handle_info/2

     warning: variable "state" is unused (if the variable is not meant to be used, prefix it with an undersc
ore)
     │
 363 │   defp validate_guild_context(word, player_id, %{guild_id: guild_id} = state) do
     │                                                                        ~~~~~
     │
     └─ lib/game_bot/game_sessions/session.ex:363:72: GameBot.GameSessions.Session.validate_guild_context/3 

     warning: variable "word" is unused (if the variable is not meant to be used, prefix it with an undersco
re)
     │
 363 │   defp validate_guild_context(word, player_id, %{guild_id: guild_id} = state) do
     │                               ~~~~
     │
     └─ lib/game_bot/game_sessions/session.ex:363:31: GameBot.GameSessions.Session.validate_guild_context/3 

     warning: variable "guild_id" is unused (if the variable is not meant to be used, prefix it with an unde
rscore)
     │
 373 │   defp player_in_guild?(player_id, guild_id) do
     │                                    ~~~~~~~~
     │
     └─ lib/game_bot/game_sessions/session.ex:373:36: GameBot.GameSessions.Session.player_in_guild?/2


     warning: variable "player_id" is unused (if the variable is not meant to be used, prefix it with an und
erscore)
     │
 373 │   defp player_in_guild?(player_id, guild_id) do
     │                         ~~~~~~~~~
     │
     └─ lib/game_bot/game_sessions/session.ex:373:25: GameBot.GameSessions.Session.player_in_guild?/2


    warning: unused alias BaseMode
    │
  9 │   alias GameBot.Domain.GameModes.BaseMode
    │   ~
    │
    └─ lib/game_bot/game_sessions/session.ex:9:3

    warning: unused alias GameEvents
    │
 13 │   alias GameBot.Domain.Events.{
    │   ~
    │
    └─ lib/game_bot/game_sessions/session.ex:13:3

     warning: GameBot.Domain.Events.GameFinished.new/4 is undefined (module GameBot.Domain.Events.GameFinish
ed is not available or is yet to be defined)
     │
 166 │         game_finished = Events.GameFinished.new(
     │                                             ~
     │
     └─ lib/game_bot/game_sessions/session.ex:166:45: GameBot.GameSessions.Session.handle_call/3

    warning: clauses with the same name should be grouped together, "def handle_event/1" was previously defi
ned (lib/game_bot/domain/projections/game_projection.ex:54)
    │
 92 │   def handle_event(%RoundStarted{} = event) do
    │       ~
    │
    └─ lib/game_bot/domain/projections/game_projection.ex:92:7

     warning: clauses with the same name should be grouped together, "def handle_event/2" was previously def
ined (lib/game_bot/domain/projections/game_projection.ex:72)
     │
 107 │   def handle_event(%RoundFinished{} = event, %{round: round}) do
     │       ~
     │
     └─ lib/game_bot/domain/projections/game_projection.ex:107:7

     warning: variable "game_id" is unused (if the variable is not meant to be used, prefix it with an under
score)
     │
 122 │   def get_game(game_id, guild_id) do
     │                ~~~~~~~
     │
     └─ lib/game_bot/domain/projections/game_projection.ex:122:16: GameBot.Domain.Projections.GameProjection
.get_game/2

     warning: variable "guild_id" is unused (if the variable is not meant to be used, prefix it with an unde
rscore)
     │
 122 │   def get_game(game_id, guild_id) do
     │                         ~~~~~~~~
     │
     └─ lib/game_bot/domain/projections/game_projection.ex:122:25: GameBot.Domain.Projections.GameProjection
.get_game/2

     warning: variable "guild_id" is unused (if the variable is not meant to be used, prefix it with an unde
rscore)
     │
 128 │   def list_active_games(guild_id) do
     │                         ~~~~~~~~
     │
     └─ lib/game_bot/domain/projections/game_projection.ex:128:25: GameBot.Domain.Projections.GameProjection
.list_active_games/1

     warning: variable "guild_id" is unused (if the variable is not meant to be used, prefix it with an unde
rscore)
     │
 133 │   def list_recent_games(guild_id, limit \\ 10) do
     │                         ~~~~~~~~
     │
     └─ lib/game_bot/domain/projections/game_projection.ex:133:25: GameBot.Domain.Projections.GameProjection
.list_recent_games/2

     warning: variable "limit" is unused (if the variable is not meant to be used, prefix it with an undersc
ore)
     │
 133 │   def list_recent_games(guild_id, limit \\ 10) do
     │                                   ~~~~~
     │
     └─ lib/game_bot/domain/projections/game_projection.ex:133:35: GameBot.Domain.Projections.GameProjection
.list_recent_games/2

     warning: variable "guild_id" is unused (if the variable is not meant to be used, prefix it with an unde
rscore)
     │
 138 │   def get_user_games(user_id, guild_id, limit \\ 10) do
     │                               ~~~~~~~~
     │
     └─ lib/game_bot/domain/projections/game_projection.ex:138:31: GameBot.Domain.Projections.GameProjection
.get_user_games/3

     warning: variable "limit" is unused (if the variable is not meant to be used, prefix it with an undersc
ore)
     │
 138 │   def get_user_games(user_id, guild_id, limit \\ 10) do
     │                                         ~~~~~
     │
     └─ lib/game_bot/domain/projections/game_projection.ex:138:41: GameBot.Domain.Projections.GameProjection
.get_user_games/3

     warning: variable "user_id" is unused (if the variable is not meant to be used, prefix it with an under
score)
     │
 138 │   def get_user_games(user_id, guild_id, limit \\ 10) do
     │                      ~~~~~~~
     │
     └─ lib/game_bot/domain/projections/game_projection.ex:138:22: GameBot.Domain.Projections.GameProjection
.get_user_games/3

     warning: variable "game_id" is unused (if the variable is not meant to be used, prefix it with an under
score)
     │
 143 │   def get_game_rounds(game_id, guild_id) do
     │                       ~~~~~~~
     │
     └─ lib/game_bot/domain/projections/game_projection.ex:143:23: GameBot.Domain.Projections.GameProjection
.get_game_rounds/2

     warning: variable "guild_id" is unused (if the variable is not meant to be used, prefix it with an unde
rscore)
     │
 143 │   def get_game_rounds(game_id, guild_id) do
     │                                ~~~~~~~~
     │
     └─ lib/game_bot/domain/projections/game_projection.ex:143:32: GameBot.Domain.Projections.GameProjection
.get_game_rounds/2

     warning: variable "guild_id" is unused (if the variable is not meant to be used, prefix it with an unde
rscore)
     │
 148 │   def get_game_statistics(guild_id, time_range \\ nil) do
     │                           ~~~~~~~~
     │
     └─ lib/game_bot/domain/projections/game_projection.ex:148:27: GameBot.Domain.Projections.GameProjection
.get_game_statistics/2

     warning: variable "time_range" is unused (if the variable is not meant to be used, prefix it with an un
derscore)
     │
 148 │   def get_game_statistics(guild_id, time_range \\ nil) do
     │                                     ~~~~~~~~~~
     │
     └─ lib/game_bot/domain/projections/game_projection.ex:148:37: GameBot.Domain.Projections.GameProjection
.get_game_statistics/2

    warning: unknown key .config in expression:

        event.config

    the given type does not have the given key:

        dynamic(%GameBot.Domain.Events.GameEvents.GameCreated{
          created_at: term(),
          created_by: term(),
          game_id: term(),
          guild_id: term(),
          metadata: term(),
          mode: term(),
          team_ids: term(),
          timestamp: term()
        })

    where "event" was given the type:

        # type: dynamic(%GameBot.Domain.Events.GameEvents.GameCreated{})
        # from: lib/game_bot/domain/projections/game_projection.ex:54:35
        %GameBot.Domain.Events.GameEvents.GameCreated{} = event

    typing violation found at:
    │
 66 │       total_rounds: event.config[:rounds] || 1
    │                           ~~~~~~
    │
    └─ lib/game_bot/domain/projections/game_projection.ex:66:27: GameBot.Domain.Projections.GameProjection.h
andle_event/1

    warning: unknown key .finished_at in expression:

        event.finished_at

    the given type does not have the given key:

        dynamic(%GameBot.Domain.Events.GameEvents.GameFinished{
          final_score: term(),
          game_id: term(),
          guild_id: term(),
          metadata: term(),
          mode: term(),
          round_number: term(),
          timestamp: term(),
          winner_team_id: term()
        })

    where "event" was given the type:

        # type: dynamic(%GameBot.Domain.Events.GameEvents.GameFinished{})
        # from: lib/game_bot/domain/projections/game_projection.ex:81:36
        %GameBot.Domain.Events.GameEvents.GameFinished{} = event

    typing violation found at:
    │
 84 │       finished_at: event.finished_at,
    │                          ~~~~~~~~~~~
    │
    └─ lib/game_bot/domain/projections/game_projection.ex:84:26: GameBot.Domain.Projections.GameProjection.h
andle_event/2

    warning: unknown key .started_at in expression:

        event.started_at

    the given type does not have the given key:

        dynamic(%GameBot.Domain.Events.GameEvents.RoundStarted{
          game_id: term(),
          guild_id: term(),
          metadata: term(),
          mode: term(),
          round_number: term(),
          team_states: term(),
          timestamp: term()
        })

    where "event" was given the type:

        # type: dynamic(%GameBot.Domain.Events.GameEvents.RoundStarted{})
        # from: lib/game_bot/domain/projections/game_projection.ex:92:36
        %GameBot.Domain.Events.GameEvents.RoundStarted{} = event

    typing violation found at:
    │
 97 │       started_at: event.started_at,
    │                         ~~~~~~~~~~
    │
    └─ lib/game_bot/domain/projections/game_projection.ex:97:25: GameBot.Domain.Projections.GameProjection.h
andle_event/1

    warning: function handle_transaction_error/2 is unused
    │
 83 │   defp handle_transaction_error(error, guild_id) do
    │        ~
    │
    └─ lib/game_bot/infrastructure/persistence/repo/transaction.ex:83:8: GameBot.Infrastructure.Persistence.
Repo.Transaction (module)

    warning: EventStore.Config.parsed/1 is undefined or private. Did you mean:

          * parsed/2

    │
 48 │       config = EventStore.Config.parsed(Application.get_env(:game_bot, :event_store) || [])
    │                                  ~
    │
    └─ lib/tasks/migrate.ex:48:34: Mix.Tasks.GameBot.Migrate.run/1

    warning: EventStore.Tasks.Migrate.run/2 is undefined or private
    │
 51 │       EventStore.Tasks.Migrate.run(config, event_store_path)
    │                                ~
    │
    └─ lib/tasks/migrate.ex:51:32: Mix.Tasks.GameBot.Migrate.run/1

    warning: variable "filtered_options" is unused (if the variable is not meant to be used, prefix it with 
an underscore)
    │
 48 │     filtered_options = Map.put(options, :guild_id, guild_id)
    │     ~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/bot/commands/replay_commands.ex:48:5: GameBot.Bot.Commands.ReplayCommands.fetch_match_hi
story/2

    warning: variable "guild_id" is unused (if the variable is not meant to be used, prefix it with an under
score)
    │
 52 │   defp fetch_game_summary(game_id, guild_id) do
    │                                    ~~~~~~~~
    │
    └─ lib/game_bot/bot/commands/replay_commands.ex:52:36: GameBot.Bot.Commands.ReplayCommands.fetch_game_su
mmary/2

    warning: variable "game_events" is unused (if the variable is not meant to be used, prefix it with an un
derscore)
    │
 62 │   defp validate_permissions(user_id, game_events) do
    │                                      ~~~~~~~~~~~
    │
    └─ lib/game_bot/bot/commands/replay_commands.ex:62:38: GameBot.Bot.Commands.ReplayCommands.validate_perm
issions/2

    warning: variable "user_id" is unused (if the variable is not meant to be used, prefix it with an unders
core)
    │
 62 │   defp validate_permissions(user_id, game_events) do
    │                             ~~~~~~~
    │
    └─ lib/game_bot/bot/commands/replay_commands.ex:62:29: GameBot.Bot.Commands.ReplayCommands.validate_perm
issions/2

    warning: variable "game_events" is unused (if the variable is not meant to be used, prefix it with an un
derscore)
    │
 67 │   defp format_replay(game_events) do
    │                      ~~~~~~~~~~~
    │
    └─ lib/game_bot/bot/commands/replay_commands.ex:67:22: GameBot.Bot.Commands.ReplayCommands.format_replay
/1

    warning: variable "matches" is unused (if the variable is not meant to be used, prefix it with an unders
core)
    │
 75 │   defp format_match_history(matches) do
    │                             ~~~~~~~
    │
    └─ lib/game_bot/bot/commands/replay_commands.ex:75:29: GameBot.Bot.Commands.ReplayCommands.format_match_
history/1

    warning: variable "game" is unused (if the variable is not meant to be used, prefix it with an underscor
e)
    │
 83 │   defp format_game_summary(game) do
    │                            ~~~~
    │
    └─ lib/game_bot/bot/commands/replay_commands.ex:83:28: GameBot.Bot.Commands.ReplayCommands.format_game_s
ummary/1

    warning: EventStore.read_stream_forward/4 is undefined or private
    │
 44 │     EventStore.read_stream_forward(game_id, 0, 1000, opts)
    │                ~
    │
    └─ lib/game_bot/bot/commands/replay_commands.ex:44:16: GameBot.Bot.Commands.ReplayCommands.fetch_game_ev
ents/2

     warning: clauses with the same name and arity (number of arguments) should be grouped together, "def ha
ndle_call/3" was previously defined (lib/game_bot/test_event_store.ex:147)
     │
 214 │   def handle_call({:unsubscribe, _stream_id, subscription}, _from, state) do
     │       ~
     │
     └─ lib/game_bot/test_event_store.ex:214:7

    warning: conflicting behaviours found. Callback function init/1 is defined by both EventStore and GenSer
ver (in module GameBot.TestEventStore)
    │
  1 │ defmodule GameBot.TestEventStore do
    │ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/test_event_store.ex:1: GameBot.TestEventStore (module)

    warning: function config/0 required by behaviour EventStore is not implemented (in module GameBot.TestEv
entStore)
    │
  1 │ defmodule GameBot.TestEventStore do
    │ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/test_event_store.ex:1: GameBot.TestEventStore (module)

    warning: function subscribe/2 required by behaviour EventStore is not implemented (in module GameBot.Tes
tEventStore)
    │
  1 │ defmodule GameBot.TestEventStore do
    │ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/test_event_store.ex:1: GameBot.TestEventStore (module)

    warning: function subscribe_to_stream/4 required by behaviour EventStore is not implemented (in module G
ameBot.TestEventStore)
    │
  1 │ defmodule GameBot.TestEventStore do
    │ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/test_event_store.ex:1: GameBot.TestEventStore (module)

    warning: function unsubscribe_from_all_streams/2 required by behaviour EventStore is not implemented (in
 module GameBot.TestEventStore)
    │
  1 │ defmodule GameBot.TestEventStore do
    │ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/test_event_store.ex:1: GameBot.TestEventStore (module)

    warning: function unsubscribe_from_stream/3 required by behaviour EventStore is not implemented (in modu
le GameBot.TestEventStore)
    │
  1 │ defmodule GameBot.TestEventStore do
    │ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/test_event_store.ex:1: GameBot.TestEventStore (module)

    warning: module attribute @impl was not set for function start_link/1 callback (specified in EventStore)
. This either means you forgot to add the "@impl true" annotation before the definition or that you are acci
dentally overriding this callback
    │
 19 │   def start_link(opts \\ []) do
    │   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/test_event_store.ex:19: GameBot.TestEventStore (module)

    warning: module attribute @impl was not set for function stop/2 callback (specified in EventStore). This
 either means you forgot to add the "@impl true" annotation before the definition or that you are accidental
ly overriding this callback
    │
 23 │   def stop(server, timeout \\ :infinity) do
    │   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/test_event_store.ex:23: GameBot.TestEventStore (module)

    warning: got "@impl EventStore" for function subscribe_to_stream/3 but this behaviour does not specify s
uch callback. The known callbacks are:

      * EventStore.subscribe/2 (function)
      * EventStore.stream_info/2 (function)
      * EventStore.delete_all_streams_subscription/2 (function)
      * EventStore.subscribe_to_stream/4 (function)
      * EventStore.record_snapshot/2 (function)
      * EventStore.delete_snapshot/2 (function)
      * EventStore.read_stream_backward/4 (function)
      * EventStore.stream_forward/3 (function)
      * EventStore.append_to_stream/4 (function)
      * EventStore.config/0 (function)
      * EventStore.start_link/1 (function)
      * EventStore.read_all_streams_backward/3 (function)
      * EventStore.read_snapshot/2 (function)
      * GenServer.code_change/3 (function)
      * EventStore.link_to_stream/4 (function)
      * GenServer.handle_info/2 (function)
      * EventStore.stop/2 (function)
      * EventStore.ack/2 (function)
      * EventStore.delete_stream/4 (function)
      * EventStore.subscribe_to_all_streams/3 (function)
      * GenServer.handle_call/3 (function)
      * EventStore.unsubscribe_from_stream/3 (function)
      * EventStore.unsubscribe_from_all_streams/2 (function)
      * EventStore.paginate_streams/1 (function)
      * GenServer.terminate/2 (function)
      * GenServer.format_status/2 (function)
      * GenServer.handle_cast/2 (function)
      * EventStore.stream_all_forward/2 (function)
      * GenServer.handle_continue/2 (function)
      * EventStore.read_all_streams_forward/3 (function)
      * EventStore.read_stream_forward/4 (function)
      * EventStore.stream_backward/3 (function)
      * EventStore.delete_subscription/3 (function)
      * EventStore.stream_all_backward/2 (function)
      * GenServer.init/1 (function)
      * EventStore.init/1 (function)
      * GenServer.format_status/1 (function)

    │
 60 │   def subscribe_to_stream(stream_id, subscriber, subscription_options \\ []) do
    │   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/test_event_store.ex:60: GameBot.TestEventStore (module)

    warning: got "@impl EventStore" for function unsubscribe_from_stream/2 but this behaviour does not speci
fy such callback. The known callbacks are:

      * EventStore.subscribe/2 (function)
      * EventStore.stream_info/2 (function)
      * EventStore.delete_all_streams_subscription/2 (function)
      * EventStore.subscribe_to_stream/4 (function)
      * EventStore.record_snapshot/2 (function)
      * EventStore.delete_snapshot/2 (function)
      * EventStore.read_stream_backward/4 (function)
      * EventStore.stream_forward/3 (function)
      * EventStore.append_to_stream/4 (function)
      * EventStore.config/0 (function)
      * EventStore.start_link/1 (function)
      * EventStore.read_all_streams_backward/3 (function)
      * EventStore.read_snapshot/2 (function)
      * GenServer.code_change/3 (function)
      * EventStore.link_to_stream/4 (function)
      * GenServer.handle_info/2 (function)
      * EventStore.stop/2 (function)
      * EventStore.ack/2 (function)
      * EventStore.delete_stream/4 (function)
      * EventStore.subscribe_to_all_streams/3 (function)
      * GenServer.handle_call/3 (function)
      * EventStore.unsubscribe_from_stream/3 (function)
      * EventStore.unsubscribe_from_all_streams/2 (function)
      * EventStore.paginate_streams/1 (function)
      * GenServer.terminate/2 (function)
      * GenServer.format_status/2 (function)
      * GenServer.handle_cast/2 (function)
      * EventStore.stream_all_forward/2 (function)
      * GenServer.handle_continue/2 (function)
      * EventStore.read_all_streams_forward/3 (function)
      * EventStore.read_stream_forward/4 (function)
      * EventStore.stream_backward/3 (function)
      * EventStore.delete_subscription/3 (function)
      * EventStore.stream_all_backward/2 (function)
      * GenServer.init/1 (function)
      * EventStore.init/1 (function)
      * GenServer.format_status/1 (function)

    │
 75 │   def unsubscribe_from_stream(stream_id, subscription) do
    │   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/game_bot/test_event_store.ex:75: GameBot.TestEventStore (module)

    warning: variable "state" is unused (if the variable is not meant to be used, prefix it with an undersco
re)
    │
 21 │   def execute(%State{} = state, %CreateTeamInvitation{} = cmd) do
    │                          ~~~~~
    │
    └─ lib/game_bot/domain/aggregates/team_aggregate.ex:21:26: GameBot.Domain.Aggregates.TeamAggregate.execu
te/2

     warning: GameBot.Infrastructure.EventStore.stream_version/1 is undefined or private. Did you mean:


           * stream_info/1
           * stream_info/2

     │
 104 │     case EventStore.stream_version(stream_id) do
     │                     ~
     │
     └─ lib/game_bot/infrastructure/event_store_adapter.ex:104:21: GameBot.Infrastructure.EventStoreAdapter.
validate_stream_size/1

** (Mix) Could not invoke task "test": 1 error found!

```

---

_****_

There seems to be compilation issues with the `EventStore` dependency. Let's try locating the original file to make our edits:

---

_****_

```bash
cd game_bot && ls -la test/bot
```

```
$ cd game_bot && ls -la test/bot

```

---

_****_

Let's use a more broad approach to find the listener test file:

---

_****_

```bash
cd game_bot && find test -name "*listen*"
```

```
$ cd game_bot && find test -name "*listen*"

```

---

_****_

Let's get all test files to see what we have:

---

_****_

```bash
cd game_bot && find test -name "*_test.exs"
```

---

_****_

Let's try using `ls` to see the structure of the test folders:

---

_****_

```bash
cd game_bot && ls -la test/game_bot/bot
```

```
$ cd game_bot && ls -la test/game_bot/bot

```

---

_****_

It seems the directory structure may be complex. Let's try to locate the file using Windows search command:

---

_****_

```bash
cd game_bot && dir /s /b listener_test.exs
```

```
$ cd game_bot && dir /s /b listener_test.exs

```

---

_****_

Let's check what Elixir test files are present in your project:

---

_****_

```bash
cd game_bot && dir /s /b *_test.exs
```

```
$ cd game_bot && dir /s /b *_test.exs

```

---

_****_

It's becoming difficult to locate the file. Let's try a more direct approach by creating a new version of the listener test that we can run:

---

_****_



---

_****_

Let's try creating it with a different file name to see if that helps:

---

_****_

```diff
- 
+ defmodule GameBot.Bot.ListenerTest do
+   use ExUnit.Case, async: false
+   import ExUnit.CaptureLog
+   import Mock
+ 
+   alias GameBot.Bot.Listener
+   alias GameBot.Test.Mocks.NostrumApiMock
+   alias Nostrum.Struct.{Message, User, Interaction}
+ 
+   # Shared fixtures to avoid recreating test data for each test
+   @valid_interaction %Interaction{
+     id: "123",
+     type: 2,
+     data: %{name: "test"},
+     token: "test_token",
+     channel_id: 123456
+   }
+ 
+   @invalid_interaction %Interaction{
+     id: "123",
+     type: 99,
+     data: %{name: "test"},
+     token: "test_token",
+     channel_id: 123456
+   }
+ 
+   @valid_message %Message{
+     id: "123",
+     content: "test message",
+     author: %User{id: "user1", bot: false},
+     channel_id: 123456,
+     mentions: []
+   }
+ 
+   @empty_message %Message{
+     id: "123",
+     content: "",
+     author: %User{id: "user1", bot: false},
+     channel_id: 123456,
+     mentions: []
+   }
+ 
+   # Use setup_all for one-time setup that can be shared across all tests
+   setup_all do
+     # Create the ETS table only once for all tests
+     if :ets.whereis(:rate_limit) == :undefined do
+       :ets.new(:rate_limit, [:named_table, :set, :public])
+     end
+ 
+     on_exit(fn ->
+       if :ets.whereis(:rate_limit) != :undefined do
+         :ets.delete_all_objects(:rate_limit)
+       end
+     end)
+ 
+     :ok
+   end
+ 
+   setup do
+     # Start the Listener only once if not already started
+     if Process.whereis(Listener) == nil do
+       {:ok, _pid} = Listener.start_link()
+     end
+ 
+     # Start NostrumApiMock
+     start_supervised!(NostrumApiMock)
+ 
+     # Clear rate limit table before each test
+     :ets.delete_all_objects(:rate_limit)
+ 
+     # Reset error simulation
+     NostrumApiMock.simulate_error(false)
+ 
+     :ok
+   end
+ 
+   # Define common mocks to reduce duplication
+   defp with_success_api_mock(test_func) do
+     mocks = [
+       {Nostrum.Api, [], [
+         create_interaction_response: fn _, _, _ -> {:ok, %{}} end,
+         create_message: fn _, _ -> {:ok, %{}} end
+       ]},
+       {GameBot.Bot.Dispatcher, [], [
+         handle_interaction: fn _ -> :ok end,
+         handle_message: fn _ -> :ok end
+       ]}
+     ]
+ 
+     with_mocks(mocks, do: test_func.())
+   end
+ 
+   defp with_error_api_mock(test_func) do
+     mocks = [
+       {Nostrum.Api, [], [
+         create_interaction_response: fn _, _, _ -> {:error, %{}} end,
+         create_message: fn _, _ -> {:error, %{}} end
+       ]},
+       {GameBot.Bot.Dispatcher, [], [
+         handle_interaction: fn _ -> {:error, :dispatcher_error} end,
+         handle_message: fn _ -> {:error, :dispatcher_error} end
+       ]}
+     ]
+ 
+     with_mocks(mocks, do: test_func.())
+   end
+ 
+   describe "handle_event/1 with interactions" do
+     test "accepts valid interaction types" do
+       with_success_api_mock(fn ->
+         assert Listener.handle_event({:INTERACTION_CREATE, @valid_interaction, nil}) == :ok
+       end)
+     end
+ 
+     test "rejects invalid interaction types" do
+       with_mocks([
+         {Nostrum.Api, [], [create_interaction_response: fn _, _, _ -> {:ok, %{}} end]}
+       ]) do
+         log = capture_log(fn ->
+           assert Listener.handle_event({:INTERACTION_CREATE, @invalid_interaction, nil}) == :error
+         end)
+ 
+         assert log =~ "Invalid interaction"
+       end
+     end
+ 
+     test "handles API errors in interaction responses" do
+       with_error_api_mock(fn ->
+         log = capture_log(fn ->
+           assert Listener.handle_event({:INTERACTION_CREATE, @valid_interaction, nil}) == :error
+         end)
+ 
+         assert log =~ "Failed to send interaction error response"
+       end)
+     end
+   end
+ 
+   describe "handle_event/1 with messages" do
+     test "accepts valid messages" do
+       with_success_api_mock(fn ->
+         assert Listener.handle_event({:MESSAGE_CREATE, @valid_message, nil}) == :ok
+       end)
+     end
+ 
+     test "rejects empty messages" do
+       with_mocks([
+         {Nostrum.Api, [], [create_message: fn _, _ -> {:ok, %{}} end]}
+       ]) do
+         log = capture_log(fn ->
+           assert Listener.handle_event({:MESSAGE_CREATE, @empty_message, nil}) == :error
+         end)
+ 
+         assert log =~ "Message validation failed"
+         assert log =~ "empty_message"
+       end
+     end
+ 
+     test "enforces rate limiting" do
+       # Simulate rate limit by adding timestamps
+       now = System.system_time(:second)
+       # Create many timestamps to exceed the limit (more efficiently)
+       timestamps = List.duplicate(now - 1, 31)
+       :ets.insert(:rate_limit, {"user1", timestamps})
+ 
+       with_mocks([
+         {Nostrum.Api, [], [create_message: fn _, _ -> {:ok, %{}} end]}
+       ]) do
+         log = capture_log(fn ->
+           assert Listener.handle_event({:MESSAGE_CREATE, @valid_message, nil}) == :error
+         end)
+ 
+         assert log =~ "Message validation failed"
+         assert log =~ "rate_limited"
+       end
+     end
+ 
+     test "detects spam messages" do
+       spam_message = %{@valid_message | content: String.duplicate("a", 2000)}
+ 
+       with_mocks([
+         {Nostrum.Api, [], [create_message: fn _, _ -> {:ok, %{}} end]}
+       ]) do
+         log = capture_log(fn ->
+           assert Listener.handle_event({:MESSAGE_CREATE, spam_message, nil}) == :error
+         end)
+ 
+         assert log =~ "Message validation failed"
+         assert log =~ "message_too_long"
+       end
+     end
+   end
+ 
+   describe "error handling" do
+     test "handles Nostrum API errors gracefully" do
+       with_error_api_mock(fn ->
+         log = capture_log(fn ->
+           assert Listener.handle_event({:MESSAGE_CREATE, @valid_message, nil}) == :error
+         end)
+ 
+         assert log =~ "Failed to send message"
+       end)
+     end
+   end
+ end
+ 
```

---

_****_

Now let's run our optimized test:

---

_****_

```bash
cd game_bot && mix test test/bot/listener_test.exs
```

---

_****_

Let's make sure the directory exists:

---

_****_

```bash
cd game_bot && mkdir -p test/bot
```

```
$ cd game_bot && mkdir -p test/bot

```

---

_****_





---



---


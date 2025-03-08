# Don't start the entire application, just load required modules
Code.require_file("lib/game_bot/infrastructure/error.ex")
Code.require_file("lib/game_bot/infrastructure/error_helpers.ex")
Code.require_file("lib/game_bot/infrastructure/persistence/event_store/serialization/behaviour.ex")
Code.require_file("lib/game_bot/infrastructure/persistence/event_store/serialization/json_serializer.ex")
Code.require_file("test/game_bot/infrastructure/persistence/event_store/serialization/standalone_serializer_test.exs")

# Configure ExUnit
ExUnit.start(capture_log: true, trace: true)

# Run just the StandaloneSerializerTest
ExUnit.configure(exclude: [:pending, :integration], include: [])
ExUnit.run()

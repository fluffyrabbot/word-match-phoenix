defmodule GameBot.Bot.ListenerTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  import Mock

  require Logger

  alias GameBot.Bot.Listener
  alias GameBot.Test.Mocks.NostrumApiMock
  alias Nostrum.Struct.{Message, User, Interaction}

  # Shared fixtures to avoid recreating test data for each test
  @valid_interaction %Interaction{
    id: "123",
    type: 2,
    data: %{name: "test"},
    token: "test_token",
    channel_id: 123456
  }

  @invalid_interaction %Interaction{
    id: "123",
    type: 99,
    data: %{name: "test"},
    token: "test_token",
    channel_id: 123456
  }

  @valid_message %Message{
    id: "123",
    content: "test message",
    author: %User{id: "user1", bot: false},
    channel_id: 123456,
    mentions: []
  }

  @empty_message %Message{
    id: "123",
    content: "",
    author: %User{id: "user1", bot: false},
    channel_id: 123456,
    mentions: []
  }

  # Use setup_all to start the Listener and Registry once before all tests
  setup_all do
    # Mock the Nostrum API
    {:ok, _} = NostrumApiMock.start_link()

    # Start the Registry using standard Elixir Registry
    # Handle the case where the registry is already started
    case Registry.start_link(keys: :unique, name: GameBot.Registry) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    # Create the rate limit table if it doesn't exist
    if :ets.whereis(:rate_limit) == :undefined do
      :ets.new(:rate_limit, [:set, :public, :named_table])
    end

    # Start the Listener GenServer
    {:ok, listener_pid} = Listener.start_link()

    # Return the listener_pid in the context
    %{listener_pid: listener_pid}
  end

  # setup context is now available in each test
  setup _context do
    # Reset mock before each test
    NostrumApiMock.simulate_error(false)

    # Clean up rate_limit table before each test
    if :ets.whereis(:rate_limit) != :undefined do
      :ets.delete_all_objects(:rate_limit)
    end

    :ok
  end

  # Define common mocks to reduce duplication
  defp with_success_api_mock(test_func) do
    mocks = [
      {Nostrum.Api, [], [
        create_interaction_response: fn _, _, _ -> {:ok, %{}} end,
        create_message: fn _, _ -> {:ok, %{}} end
      ]},
      {GameBot.Bot.Dispatcher, [], [
        handle_interaction: fn _ -> :ok end,
        handle_message: fn _ -> :ok end
      ]}
    ]

    with_mocks(mocks, do: test_func.())
  end

  defp with_error_api_mock(test_func) do
    mocks = [
      {Nostrum.Api, [], [
        create_interaction_response: fn _, _, _ -> {:error, %{}} end,
        create_message: fn _, _ -> {:error, %{}} end
      ]},
      {GameBot.Bot.Dispatcher, [], [
        handle_interaction: fn _ -> {:error, :dispatcher_error} end,
        handle_message: fn _ -> {:error, :dispatcher_error} end
      ]}
    ]

    with_mocks(mocks, do: test_func.())
  end

  describe "handle_event/1 with interactions" do
    test "accepts valid interaction types" do
      with_success_api_mock(fn ->
        assert Listener.handle_event({:INTERACTION_CREATE, @valid_interaction, nil}) == :ok
      end)
    end

    test "rejects invalid interaction types" do
      with_mocks([
        {Nostrum.Api, [], [create_interaction_response: fn _, _, _ -> {:ok, %{}} end]}
      ]) do
        log = capture_log(fn ->
          assert Listener.handle_event({:INTERACTION_CREATE, @invalid_interaction, nil}) == :error
        end)

        assert log =~ "Invalid interaction"
      end
    end

    test "handles API errors in interaction responses" do
      with_error_api_mock(fn ->
        log = capture_log(fn ->
          assert Listener.handle_event({:INTERACTION_CREATE, @valid_interaction, nil}) == :error
        end)

        assert log =~ "Failed to send interaction error response"
      end)
    end
  end

  describe "handle_event/1 with messages" do
    test "accepts valid messages" do
      with_success_api_mock(fn ->
        assert Listener.handle_event({:MESSAGE_CREATE, @valid_message, nil}) == :ok
      end)
    end

    test "rejects empty messages" do
      with_mocks([
        {Nostrum.Api, [], [create_message: fn _, _ -> {:ok, %{}} end]}
      ]) do
        log = capture_log(fn ->
          assert Listener.handle_event({:MESSAGE_CREATE, @empty_message, nil}) == :error
        end)

        assert log =~ "Message validation failed"
        assert log =~ "empty_message"
      end
    end

    test "enforces rate limiting" do
      # Simulate rate limit by adding timestamps
      now = System.system_time(:second)
      # Create many timestamps to exceed the limit (more efficiently)
      timestamps = List.duplicate(now - 1, 31)

      # Get the user ID from the valid message fixture
      user_id = @valid_message.author.id

      # Insert into the rate limit table with the correct ID
      :ets.insert(:rate_limit, {user_id, timestamps})

      with_mocks([
        {Nostrum.Api, [], [create_message: fn _, _ -> {:ok, %{}} end]}
      ]) do
        log = capture_log(fn ->
          assert Listener.handle_event({:MESSAGE_CREATE, @valid_message, nil}) == :error
        end)

        assert log =~ "Message validation failed"
        assert log =~ "rate_limited"
      end
    end

    test "detects spam messages" do
      # Create a message that's longer than the max message length (2000 chars)
      spam_message = %{@valid_message | content: String.duplicate("a", 2001)}

      with_mocks([
        {Nostrum.Api, [], [create_message: fn _, _ -> {:ok, %{}} end]}
      ]) do
        log = capture_log(fn ->
          assert Listener.handle_event({:MESSAGE_CREATE, spam_message, nil}) == :error
        end)

        assert log =~ "Message validation failed"
        assert log =~ "message_too_long"
      end
    end
  end

  describe "error handling" do
    test "handles Nostrum API errors gracefully" do
      with_error_api_mock(fn ->
        log = capture_log(fn ->
          assert Listener.handle_event({:MESSAGE_CREATE, @valid_message, nil}) == :error
        end)

        assert log =~ "Failed to send message"
      end)
    end
  end
end

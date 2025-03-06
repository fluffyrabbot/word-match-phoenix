defmodule GameBot.Bot.ListenerTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  import Mock

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

  # Use setup_all for one-time setup that can be shared across all tests
  setup_all do
    # Create the ETS table only once for all tests
    if :ets.whereis(:rate_limit) == :undefined do
      :ets.new(:rate_limit, [:named_table, :set, :public])
    end

    on_exit(fn ->
      if :ets.whereis(:rate_limit) != :undefined do
        :ets.delete_all_objects(:rate_limit)
      end
    end)

    :ok
  end

  setup do
    # Start the Listener only once if not already started
    if Process.whereis(Listener) == nil do
      {:ok, _pid} = Listener.start_link()
    end

    # Start NostrumApiMock
    start_supervised!(NostrumApiMock)

    # Clear rate limit table before each test
    :ets.delete_all_objects(:rate_limit)

    # Reset error simulation
    NostrumApiMock.simulate_error(false)

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
      :ets.insert(:rate_limit, {"user1", timestamps})

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
      spam_message = %{@valid_message | content: String.duplicate("a", 2000)}

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

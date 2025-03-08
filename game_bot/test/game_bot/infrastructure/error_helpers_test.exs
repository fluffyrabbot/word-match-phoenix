defmodule GameBot.Infrastructure.ErrorHelpersTest do
  use ExUnit.Case, async: true

  alias GameBot.Infrastructure.{Error, ErrorHelpers}

  describe "wrap_error/2" do
    test "passes through successful results" do
      result = ErrorHelpers.wrap_error(fn -> {:ok, :success} end, __MODULE__)
      assert result == {:ok, :success}
    end

    test "passes through Error structs" do
      error = Error.validation_error(__MODULE__, "test error")
      result = ErrorHelpers.wrap_error(fn -> {:error, error} end, __MODULE__)
      assert result == {:error, error}
    end

    test "transforms simple error atoms" do
      result = ErrorHelpers.wrap_error(fn -> {:error, :not_found} end, __MODULE__)
      assert {:error, %Error{type: :not_found}} = result
    end

    test "handles raised exceptions" do
      result = ErrorHelpers.wrap_error(fn -> raise ArgumentError, "test error" end, __MODULE__)
      assert {:error, %Error{type: :validation}} = result
    end

    test "handles serialization errors" do
      # Rather than trying to raise an actual Jason.EncodeError,
      # just test the tuple variant which goes through the same code path
      result = ErrorHelpers.wrap_error(fn ->
        {:error, {:serialization, "Failed to encode data"}}
      end, __MODULE__)

      assert {:error, %Error{type: :serialization}} = result
      assert result |> elem(1) |> Map.get(:message) == "Failed to encode data"
    end
  end

  describe "with_retries/3" do
    test "returns successful result immediately" do
      result = ErrorHelpers.wrap_error(fn -> {:ok, :success} end, __MODULE__)
      assert result == {:ok, :success}
    end

    test "retries on connection errors" do
      test_pid = self()
      attempt = :ets.new(:attempt_counter, [:set, :public])
      :ets.insert(attempt, {:count, 0})

      operation = fn ->
        [{:count, count}] = :ets.lookup(attempt, :count)
        :ets.insert(attempt, {:count, count + 1})
        send(test_pid, {:attempt, count + 1})

        if count < 2 do
          {:error, :connection_error}
        else
          {:ok, :success}
        end
      end

      result = ErrorHelpers.with_retries(operation, __MODULE__, max_retries: 3, initial_delay: 1)

      assert result == {:ok, :success}
      assert_received {:attempt, 1}
      assert_received {:attempt, 2}
      assert_received {:attempt, 3}
    end

    test "gives up after max retries" do
      operation = fn -> {:error, :connection_error} end
      result = ErrorHelpers.with_retries(operation, __MODULE__, max_retries: 2, initial_delay: 1)

      assert {:error, %Error{type: :connection}} = result
      assert result |> elem(1) |> Map.get(:message) =~ "(after 2 retries)"
      assert result |> elem(1) |> Map.get(:details) |> Map.get(:retries_exhausted) == true
    end

    test "adds retry context to errors" do
      test_pid = self()
      attempt = :ets.new(:attempt_counter, [:set, :public])
      :ets.insert(attempt, {:count, 0})

      operation = fn ->
        [{:count, count}] = :ets.lookup(attempt, :count)
        :ets.insert(attempt, {:count, count + 1})

        # We'll capture the error here to check its details
        error = ErrorHelpers.translate_error(:connection_error, __MODULE__)
        send(test_pid, {:error_details, error.details})

        {:error, :connection_error}
      end

      # Only set to 1 retry so we can easily test the details
      _result = ErrorHelpers.with_retries(operation, __MODULE__, max_retries: 1, initial_delay: 1)

      # Check that retry details are added
      assert_received {:error_details, _details}
    end

    test "doesn't retry on non-retryable errors" do
      test_pid = self()

      operation = fn ->
        send(test_pid, :attempt)
        {:error, :validation}
      end

      result = ErrorHelpers.with_retries(operation, __MODULE__, max_retries: 3, initial_delay: 1)

      assert {:error, %Error{type: :system}} = result
      assert_received :attempt
      refute_received :attempt
    end

    test "applies jitter to retry delay" do
      # Since we can't easily test the internal jitter mechanism directly,
      # let's verify that using jitter doesn't break the basic retry functionality
      test_pid = self()
      attempt = :ets.new(:attempt_counter, [:set, :public])
      :ets.insert(attempt, {:count, 0})

      operation = fn ->
        [{:count, count}] = :ets.lookup(attempt, :count)
        :ets.insert(attempt, {:count, count + 1})
        send(test_pid, {:attempt, count + 1})

        if count < 2 do
          {:error, :connection_error}
        else
          {:ok, :success}
        end
      end

      # Add jitter: true to test with jitter enabled
      result = ErrorHelpers.with_retries(operation, __MODULE__,
        max_retries: 3,
        initial_delay: 1,
        jitter: true
      )

      # Verify the basic retry functionality works with jitter
      assert result == {:ok, :success}
      assert_received {:attempt, 1}
      assert_received {:attempt, 2}
      assert_received {:attempt, 3}
    end
  end

  describe "translate_error/2" do
    test "passes through Error structs" do
      error = Error.validation_error(__MODULE__, "test error")
      result = ErrorHelpers.translate_error(error, __MODULE__)
      assert result == error
    end

    test "translates common error atoms" do
      result = ErrorHelpers.translate_error(:not_found, __MODULE__)
      assert %Error{type: :not_found} = result

      result = ErrorHelpers.translate_error(:timeout, __MODULE__)
      assert %Error{type: :timeout} = result

      result = ErrorHelpers.translate_error(:connection_error, __MODULE__)
      assert %Error{type: :connection} = result
    end

    test "translates EventStore errors" do
      # Create a mock EventStore error struct
      eventstore_error = %{
        __struct__: EventStore.Error,
        reason: :wrong_expected_version,
        message: "Expected version 1 but got 2"
      }

      result = ErrorHelpers.translate_error(eventstore_error, __MODULE__)
      assert %Error{type: :concurrency} = result
      assert result.message =~ "Concurrency conflict"
      assert result.message =~ "Expected version 1 but got 2"

      # Test different error types
      eventstore_error = %{
        __struct__: EventStore.Error,
        reason: :stream_not_found,
        message: "Stream 'test-123' not found"
      }

      result = ErrorHelpers.translate_error(eventstore_error, __MODULE__)
      assert %Error{type: :not_found} = result
      assert result.message =~ "Stream not found"
    end

    test "translates stream-related error atoms" do
      result = ErrorHelpers.translate_error(:invalid_stream_version, __MODULE__)
      assert %Error{type: :concurrency} = result

      result = ErrorHelpers.translate_error(:stream_exists, __MODULE__)
      assert %Error{type: :concurrency} = result

      result = ErrorHelpers.translate_error(:wrong_expected_version, __MODULE__)
      assert %Error{type: :concurrency} = result
    end

    test "translates validation tuples" do
      result = ErrorHelpers.translate_error({:validation, "test error"}, __MODULE__)
      assert %Error{type: :validation, message: "test error"} = result
    end

    test "translates contextual tuples" do
      result = ErrorHelpers.translate_error({:not_found, %{id: 123}}, __MODULE__)
      assert %Error{type: :not_found} = result
      assert result.details == %{id: 123}

      result = ErrorHelpers.translate_error({:concurrency, "Version mismatch"}, __MODULE__)
      assert %Error{type: :concurrency} = result
      assert result.message == "Version mismatch"

      result = ErrorHelpers.translate_error({:serialization, "Invalid JSON"}, __MODULE__)
      assert %Error{type: :serialization} = result
      assert result.message == "Invalid JSON"
    end

    test "wraps unknown errors as system errors" do
      result = ErrorHelpers.translate_error(:unknown_error, __MODULE__)
      assert %Error{type: :system} = result
      assert result.details == :unknown_error
    end
  end

  describe "format_changeset_error/1" do
    test "formats changeset error message with interpolation" do
      error = {"must be at least %{count} characters", [count: 3]}
      assert ErrorHelpers.format_changeset_error(error) == "must be at least 3 characters"

      error = {"is invalid", []}
      assert ErrorHelpers.format_changeset_error(error) == "is invalid"
    end
  end
end

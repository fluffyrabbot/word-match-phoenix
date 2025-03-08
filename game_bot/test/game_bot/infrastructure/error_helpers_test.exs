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

    test "translates validation tuples" do
      result = ErrorHelpers.translate_error({:validation, "test error"}, __MODULE__)
      assert %Error{type: :validation, message: "test error"} = result
    end

    test "wraps unknown errors as system errors" do
      result = ErrorHelpers.translate_error(:unknown_error, __MODULE__)
      assert %Error{type: :system} = result
      assert result.details == :unknown_error
    end
  end
end

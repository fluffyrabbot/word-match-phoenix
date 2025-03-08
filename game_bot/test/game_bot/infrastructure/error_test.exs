defmodule GameBot.Infrastructure.ErrorTest do
  use ExUnit.Case, async: true

  alias GameBot.Infrastructure.Error

  describe "new/5" do
    test "creates an error struct with all fields" do
      error = Error.new(:validation, __MODULE__, "test message", %{key: "value"}, :original_error)

      assert error.type == :validation
      assert error.context == __MODULE__
      assert error.message == "test message"
      assert error.details == %{key: "value"}
      assert error.source == :original_error
    end

    test "creates an error struct with optional fields as nil" do
      error = Error.new(:validation, __MODULE__, "test message")

      assert error.type == :validation
      assert error.context == __MODULE__
      assert error.message == "test message"
      assert error.details == nil
      assert error.source == nil
    end
  end

  describe "message/1" do
    test "formats error message with all fields" do
      error = Error.new(:validation, __MODULE__, "test message", %{key: "value"})
      message = Exception.message(error)

      assert message =~ "validation"
      assert message =~ "test message"
      assert message =~ ~s(%{key: "value"})
      assert message =~ inspect(__MODULE__)
    end
  end

  describe "helper functions" do
    test "validation_error/3" do
      error = Error.validation_error(__MODULE__, "invalid input")
      assert error.type == :validation
      assert error.message == "invalid input"
    end

    test "not_found_error/3" do
      error = Error.not_found_error(__MODULE__, "resource not found")
      assert error.type == :not_found
      assert error.message == "resource not found"
    end

    test "concurrency_error/3" do
      error = Error.concurrency_error(__MODULE__, "version mismatch")
      assert error.type == :concurrency
      assert error.message == "version mismatch"
    end

    test "timeout_error/3" do
      error = Error.timeout_error(__MODULE__, "operation timed out")
      assert error.type == :timeout
      assert error.message == "operation timed out"
    end

    test "connection_error/3" do
      error = Error.connection_error(__MODULE__, "connection failed")
      assert error.type == :connection
      assert error.message == "connection failed"
    end

    test "system_error/3" do
      error = Error.system_error(__MODULE__, "system error")
      assert error.type == :system
      assert error.message == "system error"
    end

    test "serialization_error/3" do
      error = Error.serialization_error(__MODULE__, "invalid format")
      assert error.type == :serialization
      assert error.message == "invalid format"
    end

    test "stream_size_error/3" do
      error = Error.stream_size_error(__MODULE__, "stream too large")
      assert error.type == :stream_too_large
      assert error.message == "stream too large"
    end
  end
end

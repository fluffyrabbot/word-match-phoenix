# Error Handling System Refactor Plan

## Overview

This document outlines the plan for implementing a comprehensive error handling system that provides consistent error reporting, proper error recovery, and detailed error tracking across the application.

## Phase 1: Error Types and Definitions

### 1.1 Base Error Types
- [ ] Create `GameBot.Domain.Errors` module
  ```elixir
  defmodule GameBot.Domain.Errors do
    @moduledoc """
    Defines the error types and utilities for error handling.
    """

    defmodule GameError do
      @moduledoc "Base error type for game-related errors"
      defexception [:type, :code, :message, :metadata]

      @type t :: %__MODULE__{
        type: atom(),
        code: String.t(),
        message: String.t(),
        metadata: map()
      }

      def new(type, message, metadata \\ %{}) do
        %__MODULE__{
          type: type,
          code: error_code(type),
          message: message,
          metadata: metadata
        }
      end

      def message(%{message: message, code: code}) do
        "[#{code}] #{message}"
      end

      defp error_code(type) do
        "GAME_#{type |> to_string() |> String.upcase()}"
      end
    end

    defmodule ValidationError do
      @moduledoc "Error type for validation failures"
      defexception [:field, :constraint, :message, :metadata]

      @type t :: %__MODULE__{
        field: atom() | nil,
        constraint: atom(),
        message: String.t(),
        metadata: map()
      }

      def new(constraint, message, opts \\ []) do
        %__MODULE__{
          field: Keyword.get(opts, :field),
          constraint: constraint,
          message: message,
          metadata: Keyword.get(opts, :metadata, %{})
        }
      end
    end

    defmodule CommandError do
      @moduledoc "Error type for command processing failures"
      defexception [:command, :reason, :message, :metadata]

      @type t :: %__MODULE__{
        command: struct(),
        reason: atom(),
        message: String.t(),
        metadata: map()
      }

      def new(command, reason, message, metadata \\ %{}) do
        %__MODULE__{
          command: command,
          reason: reason,
          message: message,
          metadata: metadata
        }
      end
    end

    defmodule SessionError do
      @moduledoc "Error type for session-related failures"
      defexception [:session_id, :type, :message, :metadata]

      @type t :: %__MODULE__{
        session_id: String.t(),
        type: atom(),
        message: String.t(),
        metadata: map()
      }

      def new(session_id, type, message, metadata \\ %{}) do
        %__MODULE__{
          session_id: session_id,
          type: type,
          message: message,
          metadata: metadata
        }
      end
    end
  end
  ```

### 1.2 Error Context
- [ ] Create `GameBot.Domain.Errors.Context` module
  ```elixir
  defmodule GameBot.Domain.Errors.Context do
    @moduledoc """
    Provides context for error handling and tracking.
    """

    defstruct [:request_id, :user_id, :guild_id, :session_id, :timestamp, :metadata]

    @type t :: %__MODULE__{
      request_id: String.t(),
      user_id: String.t() | nil,
      guild_id: String.t() | nil,
      session_id: String.t() | nil,
      timestamp: DateTime.t(),
      metadata: map()
    }

    def new(opts \\ []) do
      %__MODULE__{
        request_id: generate_request_id(),
        user_id: Keyword.get(opts, :user_id),
        guild_id: Keyword.get(opts, :guild_id),
        session_id: Keyword.get(opts, :session_id),
        timestamp: DateTime.utc_now(),
        metadata: Keyword.get(opts, :metadata, %{})
      }
    end

    def from_command(command) do
      new(
        user_id: Map.get(command, :user_id),
        guild_id: Map.get(command, :guild_id),
        session_id: Map.get(command, :game_id),
        metadata: %{
          command_type: command.__struct__
        }
      )
    end

    defp generate_request_id do
      :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
    end
  end
  ```

## Phase 2: Error Handling Infrastructure

### 2.1 Error Handler
- [ ] Create `GameBot.Domain.Errors.Handler` module
  ```elixir
  defmodule GameBot.Domain.Errors.Handler do
    @moduledoc """
    Central error handling and reporting system.
    """

    require Logger
    alias GameBot.Domain.Errors.Context

    def handle_error(error, context \\ nil) do
      context = context || Context.new()
      
      # Log error
      log_error(error, context)

      # Track error metrics
      track_error(error, context)

      # Notify if necessary
      maybe_notify(error, context)

      # Return formatted error
      format_error(error, context)
    end

    def handle_errors(errors, context \\ nil) when is_list(errors) do
      context = context || Context.new()
      
      Enum.map(errors, &handle_error(&1, context))
    end

    defp log_error(error, context) do
      Logger.error(
        "Error occurred",
        error: error,
        request_id: context.request_id,
        user_id: context.user_id,
        guild_id: context.guild_id,
        session_id: context.session_id
      )
    end

    defp track_error(error, context) do
      :telemetry.execute(
        [:game_bot, :errors, error_type(error)],
        %{count: 1},
        %{
          error: error,
          context: context
        }
      )
    end

    defp maybe_notify(error, context) do
      if should_notify?(error) do
        # Send notification
        :ok
      end
    end

    defp format_error(error, _context) do
      case error do
        %GameBot.Domain.Errors.GameError{} = e ->
          {:error, :game_error, e.code, e.message}
        %GameBot.Domain.Errors.ValidationError{} = e ->
          {:error, :validation_error, e.constraint, e.message}
        %GameBot.Domain.Errors.CommandError{} = e ->
          {:error, :command_error, e.reason, e.message}
        %GameBot.Domain.Errors.SessionError{} = e ->
          {:error, :session_error, e.type, e.message}
        _ ->
          {:error, :unknown_error, "internal_error", "An unexpected error occurred"}
      end
    end

    defp error_type(%GameBot.Domain.Errors.GameError{}), do: :game_error
    defp error_type(%GameBot.Domain.Errors.ValidationError{}), do: :validation_error
    defp error_type(%GameBot.Domain.Errors.CommandError{}), do: :command_error
    defp error_type(%GameBot.Domain.Errors.SessionError{}), do: :session_error
    defp error_type(_), do: :unknown_error

    defp should_notify?(%GameBot.Domain.Errors.GameError{type: :critical}), do: true
    defp should_notify?(%GameBot.Domain.Errors.SessionError{type: :crash}), do: true
    defp should_notify?(_), do: false
  end
  ```

### 2.2 Error Middleware
- [ ] Create `GameBot.Domain.Errors.Middleware` module
  ```elixir
  defmodule GameBot.Domain.Errors.Middleware do
    @moduledoc """
    Middleware for handling errors in the command pipeline.
    """

    alias GameBot.Domain.Errors.{Context, Handler}

    def handle_error(error, command) do
      context = Context.from_command(command)
      Handler.handle_error(error, context)
    end

    def wrap_command(command, fun) do
      try do
        fun.(command)
      rescue
        e in [GameBot.Domain.Errors.GameError,
              GameBot.Domain.Errors.ValidationError,
              GameBot.Domain.Errors.CommandError,
              GameBot.Domain.Errors.SessionError] ->
          handle_error(e, command)
        e ->
          handle_error(
            GameBot.Domain.Errors.GameError.new(:internal_error, "Unexpected error occurred"),
            command
          )
      end
    end
  end
  ```

## Phase 3: Integration

### 3.1 Command Integration
- [ ] Update command handling
  ```elixir
  defmodule GameBot.Domain.Commands.Router do
    alias GameBot.Domain.Errors.Middleware

    def dispatch(command) do
      Middleware.wrap_command(command, fn cmd ->
        # Process command
        handle_command(cmd)
      end)
    end
  end
  ```

### 3.2 Session Integration
- [ ] Update session error handling
  ```elixir
  defmodule GameBot.GameSessions.Session do
    alias GameBot.Domain.Errors.Handler

    def handle_info({:EXIT, _pid, reason}, state) do
      context = %{
        session_id: state.session_id,
        guild_id: state.guild_id
      }

      Handler.handle_error(
        GameBot.Domain.Errors.SessionError.new(
          state.session_id,
          :crash,
          "Session crashed: #{inspect(reason)}"
        ),
        context
      )

      {:stop, :normal, state}
    end
  end
  ```

## Phase 4: Error Reporting

### 4.1 Error Metrics
- [ ] Create error metrics module
  ```elixir
  defmodule GameBot.Domain.Errors.Metrics do
    use Prometheus.Metric

    def setup do
      Counter.declare(
        name: :game_bot_errors_total,
        help: "Total number of errors",
        labels: [:type, :code]
      )

      Counter.declare(
        name: :game_bot_error_handling_duration_seconds,
        help: "Time spent handling errors",
        labels: [:type]
      )
    end

    def record_error(type, code) do
      Counter.inc(
        name: :game_bot_errors_total,
        labels: [type, code]
      )
    end

    def observe_handling_duration(type, duration) do
      Histogram.observe(
        name: :game_bot_error_handling_duration_seconds,
        labels: [type],
        value: duration
      )
    end
  end
  ```

### 4.2 Error Reporting
- [ ] Create error reporting module
  ```elixir
  defmodule GameBot.Domain.Errors.Reporter do
    @moduledoc """
    Reports errors to external services.
    """

    def report_error(error, context) do
      # Report to external service
      :ok
    end

    def report_errors(errors, context) when is_list(errors) do
      Enum.each(errors, &report_error(&1, context))
    end
  end
  ```

## Success Criteria

1. **Error Handling**
   - All errors properly caught
   - Clear error messages
   - Proper error types

2. **Error Recovery**
   - Graceful degradation
   - State consistency
   - Resource cleanup

3. **Error Reporting**
   - Detailed error logs
   - Error metrics
   - Error notifications

## Migration Strategy

1. **Phase 1: Development (2 days)**
   - Implement error types
   - Add error handling
   - Create middleware

2. **Phase 2: Integration (2 days)**
   - Update commands
   - Update sessions
   - Add monitoring

3. **Phase 3: Testing (1 day)**
   - Error scenarios
   - Recovery tests
   - Load tests

4. **Phase 4: Deployment (1 day)**
   - Gradual rollout
   - Monitor errors
   - Document changes

## Risks and Mitigation

### Error Propagation
- **Risk**: Missing error cases
- **Mitigation**: Comprehensive testing

### Performance Impact
- **Risk**: Slow error handling
- **Mitigation**: Async processing

### Error Recovery
- **Risk**: Inconsistent state
- **Mitigation**: Proper cleanup 
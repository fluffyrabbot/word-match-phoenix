# Command Handling Refactor Plan

## Overview

This document outlines the plan for refactoring the command handling system to use a more structured approach with proper validation, routing, and error handling. This will improve reliability and maintainability of the command processing pipeline.

## Phase 1: Command Structure

### 1.1 Base Command Module
- [ ] Create `GameBot.Domain.Commands.Command` module
  ```elixir
  defmodule GameBot.Domain.Commands.Command do
    @moduledoc """
    Base behaviour and utilities for commands.
    """

    @callback validate(command :: struct()) :: :ok | {:error, term()}
    @callback handle(command :: struct()) :: {:ok, term()} | {:error, term()}
    @callback rollback(command :: struct(), reason :: term()) :: :ok | {:error, term()}

    defmacro __using__(_opts) do
      quote do
        @behaviour GameBot.Domain.Commands.Command
        use Ecto.Schema
        import Ecto.Changeset

        def validate(command) do
          command
          |> changeset(%{})
          |> case do
            %{valid?: true} -> :ok
            changeset -> {:error, changeset}
          end
        end

        def rollback(_command, _reason), do: :ok

        defoverridable [validate: 1, rollback: 2]
      end
    end
  end
  ```

### 1.2 Command Definitions
- [ ] Create game-related commands
  ```elixir
  defmodule GameBot.Domain.Commands.GameCommands do
    defmodule StartGame do
      use GameBot.Domain.Commands.Command

      @primary_key false
      embedded_schema do
        field :game_id, :string
        field :guild_id, :string
        field :mode, Ecto.Enum, values: [:two_player, :knockout, :race]
        field :options, :map, default: %{}
      end

      def changeset(command, attrs) do
        command
        |> cast(attrs, [:game_id, :guild_id, :mode, :options])
        |> validate_required([:game_id, :guild_id, :mode])
        |> validate_mode_options()
      end

      def handle(command) do
        GameBot.GameSessions.start_game(command.game_id, Map.from_struct(command))
      end

      defp validate_mode_options(changeset) do
        validate_change(changeset, :options, fn :options, options ->
          case get_field(changeset, :mode) do
            :knockout when not is_integer(options[:max_teams]) ->
              [options: "knockout mode requires max_teams option"]
            :race when not is_integer(options[:time_limit]) ->
              [options: "race mode requires time_limit option"]
            _ -> []
          end
        end)
      end
    end

    defmodule ProcessGuess do
      use GameBot.Domain.Commands.Command

      @primary_key false
      embedded_schema do
        field :game_id, :string
        field :team_id, :string
        field :player_id, :string
        field :word, :string
      end

      def changeset(command, attrs) do
        command
        |> cast(attrs, [:game_id, :team_id, :player_id, :word])
        |> validate_required([:game_id, :team_id, :player_id, :word])
        |> validate_word_format()
      end

      def handle(command) do
        GameBot.GameSessions.process_guess(command.game_id, Map.from_struct(command))
      end

      defp validate_word_format(changeset) do
        validate_change(changeset, :word, fn :word, word ->
          if String.match?(word, ~r/^[a-zA-Z]+$/) do
            []
          else
            [word: "must contain only letters"]
          end
        end)
      end
    end
  end
  ```

## Phase 2: Command Pipeline

### 2.1 Command Middleware
- [ ] Create middleware modules
  ```elixir
  defmodule GameBot.Domain.Commands.Middleware do
    @type command :: struct()
    @type middleware_response :: {:ok, command()} | {:error, term()}
    @type middleware_fn :: (command() -> middleware_response())

    defmodule Validation do
      def execute(command) do
        case command.__struct__.validate(command) do
          :ok -> {:ok, command}
          error -> error
        end
      end
    end

    defmodule Telemetry do
      def execute(command) do
        start = System.monotonic_time()
        result = {:ok, command}
        duration = System.monotonic_time() - start

        :telemetry.execute(
          [:game_bot, :commands, :processed],
          %{duration: duration},
          %{
            command: command.__struct__,
            result: result
          }
        )

        result
      end
    end

    defmodule ErrorHandler do
      def execute(command) do
        try do
          {:ok, command}
        rescue
          e ->
            :telemetry.execute(
              [:game_bot, :commands, :error],
              %{count: 1},
              %{
                command: command.__struct__,
                error: e
              }
            )
            {:error, e}
        end
      end
    end
  end
  ```

### 2.2 Command Router
- [ ] Create command router
  ```elixir
  defmodule GameBot.Domain.Commands.Router do
    use GenServer

    alias GameBot.Domain.Commands.Middleware

    def start_link(_) do
      GenServer.start_link(__MODULE__, [], name: __MODULE__)
    end

    def dispatch(command) do
      GenServer.call(__MODULE__, {:dispatch, command})
    end

    def init(_) do
      {:ok, %{}}
    end

    def handle_call({:dispatch, command}, _from, state) do
      result =
        command
        |> apply_middleware(Middleware.Validation)
        |> apply_middleware(Middleware.Telemetry)
        |> apply_middleware(Middleware.ErrorHandler)
        |> execute_command()

      {:reply, result, state}
    end

    defp apply_middleware({:ok, command}, middleware) do
      middleware.execute(command)
    end
    defp apply_middleware(error, _middleware), do: error

    defp execute_command({:ok, command}) do
      command.__struct__.handle(command)
    end
    defp execute_command(error), do: error
  end
  ```

## Phase 3: Integration

### 3.1 Discord Command Integration
- [ ] Update Discord command handlers
  ```elixir
  defmodule GameBot.Bot.CommandHandler do
    alias GameBot.Domain.Commands.{Router, GameCommands}

    def handle_interaction(interaction) do
      case build_command(interaction) do
        {:ok, command} -> Router.dispatch(command)
        error -> error
      end
    end

    defp build_command(%{data: %{name: "start"}} = interaction) do
      %GameCommands.StartGame{
        game_id: generate_game_id(),
        guild_id: interaction.guild_id,
        mode: get_mode_from_options(interaction.data.options),
        options: get_additional_options(interaction.data.options)
      }
    end

    defp build_command(%{data: %{name: "guess"}} = interaction) do
      %GameCommands.ProcessGuess{
        game_id: get_game_id_from_options(interaction.data.options),
        team_id: get_team_id(interaction),
        player_id: interaction.user.id,
        word: get_word_from_options(interaction.data.options)
      }
    end
  end
  ```

### 3.2 Session Integration
- [ ] Update session handling
  ```elixir
  defmodule GameBot.GameSessions do
    def dispatch_command(game_id, command) do
      GameBot.Domain.Commands.Router.dispatch(command)
    end
  end
  ```

## Phase 4: Testing

### 4.1 Command Tests
- [ ] Create command test modules
  ```elixir
  defmodule GameBot.Domain.Commands.GameCommandsTest do
    use GameBot.DataCase
    alias GameBot.Domain.Commands.GameCommands

    describe "StartGame" do
      test "validates required fields" do
        command = %GameCommands.StartGame{}
        assert {:error, changeset} = GameCommands.StartGame.validate(command)
        assert "can't be blank" in errors_on(changeset).game_id
      end

      test "validates mode options" do
        command = %GameCommands.StartGame{
          game_id: "test",
          guild_id: "guild",
          mode: :knockout,
          options: %{}
        }
        assert {:error, changeset} = GameCommands.StartGame.validate(command)
        assert "knockout mode requires max_teams option" in errors_on(changeset).options
      end
    end
  end
  ```

### 4.2 Integration Tests
- [ ] Create integration test modules
  ```elixir
  defmodule GameBot.Domain.Commands.IntegrationTest do
    use GameBot.DataCase
    alias GameBot.Domain.Commands.Router

    test "processes command through pipeline" do
      command = %GameCommands.StartGame{
        game_id: "test",
        guild_id: "guild",
        mode: :two_player,
        options: %{}
      }

      assert {:ok, _result} = Router.dispatch(command)
    end
  end
  ```

## Success Criteria

1. **Command Validation**
   - All commands properly validated
   - Clear error messages
   - Type safety

2. **Performance**
   - Command processing < 50ms
   - Error rate < 0.1%
   - Memory usage stable

3. **Monitoring**
   - Command metrics tracked
   - Error tracking
   - Performance monitoring

## Migration Strategy

1. **Phase 1: Development (2 days)**
   - Implement command structure
   - Add validation
   - Create middleware

2. **Phase 2: Integration (2 days)**
   - Update Discord handlers
   - Update sessions
   - Add monitoring

3. **Phase 3: Testing (1 day)**
   - Unit tests
   - Integration tests
   - Load tests

4. **Phase 4: Deployment (1 day)**
   - Gradual rollout
   - Monitor metrics
   - Document changes

## Risks and Mitigation

### Validation Risks
- **Risk**: Missing edge cases
- **Mitigation**: Comprehensive testing

### Performance Risks
- **Risk**: Pipeline overhead
- **Mitigation**: Benchmark critical paths

### Integration Risks
- **Risk**: Breaking changes
- **Mitigation**: Gradual rollout 
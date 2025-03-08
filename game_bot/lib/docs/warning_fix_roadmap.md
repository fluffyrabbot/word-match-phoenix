# Warning Fix Roadmap

This document outlines a prioritized approach to addressing the warnings in the GameBot codebase. The warnings have been categorized by severity and impact, with recommended fixes for each category.

## Priority Levels

- **P0 (Critical)**: Can cause runtime errors or serious issues
- **P1 (High)**: Likely to cause problems in the future or indicates architectural issues
- **P2 (Medium)**: Best practice violations that should be fixed
- **P3 (Low)**: Minor style issues or unused declarations

## Warning Categories

### P0: Critical Issues

- [ ] **Behaviour Implementation Errors**
  - Fix missing `@impl true` annotations for behaviour callbacks
  - Fix functions marked with `@impl true` that don't actually implement a behaviour callback
  - Example: `warning: module attribute @impl was not set for function ack/2 callback (specified in EventStore).`

- [ ] **Undefined Function Calls**
  - Address calls to undefined functions or modules
  - Example: `GameBot.Infrastructure.Persistence.EventStore.Adapter.read_stream_forward/4 is undefined`
  - Example: `GameBot.Domain.Events.ErrorEvents.RoundCheckError.new/2 is undefined`

- [ ] **Multiple Clause Default Parameter Issues**
  - Fix function definitions with multiple clauses that define default parameters incorrectly
  - Example: `def from_discord_message/2 has multiple clauses and also declares default values`

### P1: High Priority Issues

- [ ] **Conflicting Behaviours**
  - Resolve modules that implement multiple behaviours with conflicting callbacks
  - Example: `conflicting behaviours found. Callback function init/1 is defined by both GenServer and EventStore`

- [ ] **Inconsistent Function Group Ordering**
  - Group related function clauses together
  - Example: `clauses with the same name should be grouped together`

- [ ] **Event System Issues**
  - Fix validation in event modules
  - Address inconsistent event versioning
  - Resolve event serialization/deserialization issues

- [ ] **Duplicate Documentation**
  - Remove or consolidate duplicate documentation
  - Example: `redefining @doc attribute previously set at line 96`

### P2: Medium Priority Issues

- [ ] **Unused Aliases and Imports**
  - Remove unnecessary aliases
  - Example: `warning: unused alias Multi`
  - Example: `warning: unused import Ecto.Query`

- [ ] **Unused Functions**
  - Remove or document functions that are defined but never called
  - Example: `warning: function count_active_teams/1 is unused`

- [ ] **Unused Type Definitions**
  - Remove or document type specs that are defined but never used
  - Example: `warning: type conn/0 is unused`

- [ ] **Unused Module Attributes**
  - Remove unused module attributes
  - Example: `warning: module attribute @base_fields was set but never used`

### P3: Low Priority Issues

- [ ] **Unused Variables**
  - Prefix unused variables with underscore
  - Example: `warning: variable "msg" is unused (if the variable is not meant to be used, prefix it with an underscore)`

- [ ] **Map Key Overrides**
  - Fix instances where map keys are overridden
  - Example: `warning: key :round_number will be overridden in map`

## Holistic Improvements

Rather than addressing each warning individually, consider these broader architectural improvements that would fix multiple warnings at once:

### 1. Event System Refactoring

**Difficulty**: High (requires deep understanding of the event system, major code changes)

**Issues Addressed:**
- Inconsistent event versioning
- Missing `@impl true` annotations
- Incorrect validation callbacks
- Undefined functions in event handling

**Suggested Approach:**
```elixir
# Create a standardized event module generator
defmodule GameBot.Domain.Events.Generator do
  defmacro define_event(name, fields, opts \\ []) do
    quote do
      defmodule unquote(name) do
        @behaviour GameBot.Domain.Events.GameEvents
        
        @impl true
        def event_type, do: unquote(opts[:type] || to_string(name))
        
        @impl true
        def event_version, do: unquote(opts[:version] || 1)
        
        # Generate struct with fields...
        
        @impl true
        def validate(event), do: validate_fields(event)
        
        # Generate other required callbacks...
      end
    end
  end
end
```

### 2. Connection Management Framework

**Difficulty**: Medium (focused scope, moderate implementation complexity)

**Issues Addressed:**
- Database timeout issues
- Connection cleanup inconsistencies
- Resource leaks

**Suggested Approach:**
```elixir
defmodule GameBot.Test.DatabaseLifecycle do
  # Standardized connection management for tests
  def with_clean_database(test_fun) do
    # Cleanup before
    close_all_connections()
    reset_database_state()
    
    try do
      test_fun.()
    after
      # Cleanup after
      close_all_connections()
    end
  end
  
  # Other helper functions...
end
```

### 3. Behaviour Compliance Checker

**Difficulty**: Medium-High (requires introspection capabilities, careful testing)

**Issues Addressed:**
- Missing or incorrect `@impl true` annotations
- Conflicting behaviour implementations
- Inconsistent callback implementations

**Suggested Approach:**
Create a Mix task to validate all modules against their declared behaviours and suggest fixes.

### 4. Alias and Import Manager

**Difficulty**: Low-Medium (straightforward concept, but requires thorough analysis)

**Issues Addressed:**
- Unused aliases and imports
- Inconsistent module references

**Suggested Approach:**
Create a linting tool specifically for alias and import optimization.

### 5. Enhanced Test Framework

**Difficulty**: Medium (builds on existing test patterns, requires coordination)

**Issues Addressed:**
- Inconsistent test setup
- Database connection issues in tests
- Missing cleanup in tests

**Suggested Approach:**
Create a standardized test framework with proper lifecycle management.

## Implementation Plan

1. **Phase 1 (Immediate)**
   - Fix all P0 critical issues
   - Implement the Connection Management Framework
   - Address the most critical EventStore-related issues

2. **Phase 2 (Short-term)**
   - Fix P1 high priority issues
   - Implement Event System Refactoring
   - Develop the Behaviour Compliance Checker

3. **Phase 3 (Medium-term)**
   - Fix P2 medium priority issues
   - Implement Enhanced Test Framework
   - Refine documentation

4. **Phase 4 (Long-term)**
   - Fix P3 low priority issues
   - Implement Alias and Import Manager
   - Continuous monitoring for new warnings

## Development Practices Going Forward

To prevent accumulation of warnings in the future:

1. **Add Strict Compiler Flags**: Configure the build system to treat warnings as errors in CI/CD.

2. **Regular Warning Audits**: Schedule regular code reviews focused on addressing warnings.

3. **Style Guide Updates**: Update the style guide to address common warning sources.

4. **Automated Linting**: Incorporate Credo or similar tools to catch issues early.

5. **Shared Knowledge**: Document common pitfalls and their solutions for the development team.

6. **Test Coverage Improvements**: Ensure high test coverage to catch issues that warnings might indicate. 
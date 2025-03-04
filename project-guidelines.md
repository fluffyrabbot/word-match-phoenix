# Project Guidelines

## Core Principles

### Architectural Integrity
- **No New Features** unless explicitly requested
- Maintain established module boundaries
- Follow existing design patterns
- Use existing components/services
- Report inconsistencies rather than fixing without approval

### Implementation Rules
- Focus on specific tasks requested
- Verify code against architecture before submitting
- Recommend options when uncertain, don't make assumptions
- Keep changes reversible and minimal

## Module Boundaries

| Module | Responsibility | Constraints |
|--------|----------------|-------------|
| Bot | Discord integration | Use Nostrum library, route events to domain |
| Domain/GameModes | Game rules implementation | Pure business logic, no DB or Discord dependencies |
| Domain/Events | Event definitions | Immutable, serializable, versioned |
| Domain/Commands | Command processing | Validate before generating events |
| Infrastructure/Repo | Data persistence | Ecto schemas, no domain logic |
| Infrastructure/Cache | Performance optimization | ETS-based, transparent fallback to DB |
| Web | Optional HTTP interface | Phoenix controllers, no direct domain logic |

## Elixir Architecture Patterns
- Follow functional programming principles
- Use GenServers for stateful game sessions
- Implement CQRS with commands and events
- Build supervision trees for fault tolerance
- Leverage pattern matching for command handling

## Implementation Workflow

1. **Analyze**: Understand existing code and patterns
2. **Plan**: Identify minimal changes needed
3. **Implement**: Follow established patterns
4. **Verify**: Ensure compliance with guidelines

## Terminal Usage
- Use Git Bash syntax for commands
- Break large changes into smaller commits
- Create descriptive commit messages 
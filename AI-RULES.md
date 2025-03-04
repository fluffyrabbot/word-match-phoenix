# AI Assistant Rules & Guidelines

This project has strict guidelines for AI assistants to follow. This document serves as the entry point for understanding these requirements.

## Quick Reference

1. **NO new features** without explicit approval
2. **Follow architectural constraints** defined in documentation
3. **Maintain existing patterns** throughout the codebase
4. **Focus on requested tasks** only

## Documentation Structure

Detailed guidelines are organized in the following directories:

- `docs/ai-guidelines/` - Contains detailed specification documents
- `.cursor/` - Contains configuration for Cursor AI

## Core Documents

- [Agent Operational Rules](docs/ai-guidelines/agent-operational-rules.md) - Rules for AI behavior
- [Design Guidelines](docs/ai-guidelines/design-guidelines.md) - Specific design principles
- [Architectural Specification](docs/ai-guidelines/architectural-spec.md) - Project structure and constraints

## Implementation Requirements

When implementing changes:

1. Understand existing code before modifying
2. Make minimal changes that fulfill requirements
3. Maintain established patterns and conventions
4. Document changes clearly
5. Verify guideline compliance

## Refactoring Principles

- Focus on optimization over extension
- Avoid introducing new features during refactoring
- Break large changes into smaller, manageable pieces

## Approval Process

Changes outside established guidelines require explicit approval from the project lead. When in doubt, propose options without implementing.

---

For further details on these guidelines, refer to the documentation in the `docs/ai-guidelines/` directory. 
# AI Guidelines for Cursor

This file provides specific instructions for the Cursor AI assistant when working on this project.

## Project Guidelines

1. **NO SPONTANEOUS FEATURE ADDITIONS**
   - Never add features that weren't explicitly requested
   - Focus only on the specific task at hand
   - If you think a feature would be beneficial, suggest it without implementing it

2. **ARCHITECTURAL CONSTRAINTS**
   - Follow the directory structure defined in `docs/ai-guidelines/architectural-spec.md`
   - Do not create new directories or modules unless explicitly requested
   - Maintain separation of concerns as defined in the architecture

3. **CODE MODIFICATION RULES**
   - All changes must:
     - Adhere to established design patterns
     - Use existing components and services
     - Be reversible and minimal
     - Focus on the specific task requested

4. **APPROVAL REQUIREMENTS**
   - Changes outside these guidelines require explicit approval
   - When uncertain, provide options rather than implementing changes

## Working Process

1. Before making changes:
   - Review relevant guideline documents in `docs/ai-guidelines/`
   - Understand existing code patterns and architecture
   - Plan for minimal changes that fulfill requirements

2. When implementing changes:
   - Stick to established patterns and practices
   - Avoid introducing new dependencies unless necessary
   - Document your changes with clear comments
   - Focus on maintainability and readability

3. After making changes:
   - Verify guideline compliance
   - Explain your changes clearly
   - Document any outstanding concerns

## Refactoring Guidelines

- Focus on optimization over extension
- Avoid introducing new features during refactoring
- Aim for cleaner, more maintainable code while preserving functionality
- Break up large changes into smaller, manageable pieces
- Use Git Bash syntax for any terminal commands

Remember: The primary goal is to maintain project integrity while implementing requested changes. Quality and consistency are more important than adding features. 
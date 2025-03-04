## SpecStory

## AI Guidelines for Cursor Interaction (3/3/2025, 9:33:34 PM)

_**User**_

do you see the ai guidelines for cursor

---

_**Assistant**_

<think>
The user is asking me if I can see their "AI guidelines for Cursor", which I assume refers to the custom instructions they've provided. Let me check what information I have access to based on the user's query.

I do see the custom instructions provided at the beginning of their message:

1. Use git bash syntax when running tools or commands
2. Break up diffs for large files or large number of lines into smaller diffs
3. During refactoring, avoid introducing new features and avoid extending functionality
4. Don't spontaneously extend functionality when creating diffs unless explicitly asked
5. Feel free to suggest functionality extensions without putting them in diffs/edits
6. When implementing or refactoring features, focus on optimization over extension

These appear to be guidelines for how I should interact with them when writing code and using tools, particularly when creating diffs and editing files. These instructions emphasize keeping changes minimal and focused on the task at hand rather than extending functionality unnecessarily.

I should acknowledge that I can see these guidelines.
</think>

Yes, I can see the AI guidelines you've provided for Cursor. They include:

1. Using git bash syntax for commands
2. Breaking up large diffs into smaller parts
3. Avoiding new feature introduction during refactoring
4. Not extending functionality in diffs unless explicitly requested
5. Focusing on optimization rather than extension when implementing features

I'll follow these guidelines in our interactions when working with your code. Is there a specific project or task you'd like to work on next?

---

_**User**_

i just changed them. critique the structure

---

_**Assistant**_

<think>
Let me analyze the structure of the custom instructions you provided. Here's my critique of the structure:

The custom instructions are organized in the following way:

1. **Core Rules**
   - Four main rules are listed: NO NEW FEATURES, MAINTAIN ARCHITECTURE, FOLLOW PATTERNS, MINIMIZE CHANGES
   - Each rule has bullet points explaining what it means in practice

2. **Process Checklist**
   - A list of checkmarks for the process to follow
   - Includes understanding existing code, planning minimal changes, following patterns, documenting changes, and verifying guideline compliance

3. **Terminal Usage**
   - Guidelines for terminal commands and Git practices
   - Emphasizes Git Bash syntax, breaking up large diffs, and clear commit messages

Overall, it's a well-structured set of guidelines that covers important aspects of software development in a clear, hierarchical format. I should provide a critique of this structure.
</think>

Your updated AI guidelines have a very clear and well-organized structure:

1. **Core Rules Section** - Effectively categorizes the primary principles into four key areas:
   - NO NEW FEATURES - Clear boundaries about scope
   - MAINTAIN ARCHITECTURE - Preserves project organization
   - FOLLOW PATTERNS - Ensures consistency
   - MINIMIZE CHANGES - Promotes precision and safety

2. **Process Checklist** - The checkmark format provides a quick reference for the proper workflow sequence, making it easy to verify each step is followed.

3. **Terminal Usage** - Properly separates terminal-specific instructions which is helpful for ensuring consistent command execution.

The hierarchical organization makes these guidelines scannable and actionable. The bulleted format under each main section provides clear elaboration without becoming overwhelming.

One potential improvement might be adding a version number or date to track when these guidelines were last updated, especially if they evolve over time.

---

_**User**_

is the more detailed version i switched to better or worse

---

_**Assistant**_

<think>
I need to compare the current, more detailed version to what seems to have been a simpler version before. The current guidelines I can see are quite comprehensive and include:

1. Project Overview
2. Personality Instructions
3. Agent Operational Rules (with 4 subsections)
4. Design Guidelines (with 4 subsections)
5. Project Structure
6. Module Responsibilities (with detailed responsibilities for Components, Services, Utils)
7. Implementation Process (3 stages)
8. Refactoring Guidelines
9. Tech Stack & Process Details

This is indeed a much more detailed and structured approach compared to what was implied in my previous response (which mentioned a simpler format with Core Rules, Process Checklist, and Terminal Usage sections).
</think>

The more detailed version you switched to is significantly better for several reasons:

1. **Comprehensive Guidance**: It provides much more thorough instructions covering personality, operational rules, design principles, and implementation processes.

2. **Structural Clarity**: The organization into major sections (Project Overview, Agent Operational Rules, Design Guidelines, etc.) creates a clear hierarchy of information.

3. **Specific Role Definition**: The "Personality Instructions" section helps establish the expected mindset and approach.

4. **Project Architecture Documentation**: Including the project structure and module responsibilities provides crucial context for making informed decisions.

5. **Implementation Workflow**: Breaking down the implementation process into before/during/after phases creates a systematic approach to changes.

6. **Technical Specificity**: The module responsibilities section clearly defines what belongs where, reducing ambiguity.

The previous version appeared to be more condensed with simpler categorization. This expanded version provides significantly more guardrails and specific guidance that will lead to more consistent and architecturally sound results.

---

_**User**_

is the token count not an issue? if you were to suggest slimming it down, what would you slim down?

---

_**Assistant**_

<think>
You're asking about token efficiency and potential areas to slim down in the custom instructions.

Let me analyze the token usage concerns:

1. Token count is indeed a consideration for custom instructions, as they consume some of your available context window.

2. The current detailed instructions are comprehensive but potentially use more tokens than necessary.

Areas that could be slimmed down without losing critical information:

1. Project Structure: The directory listing could be shortened or removed if you're working within an established project where the structure is already visible.

2. Redundancies: There's some repetition between sections (e.g., architectural adherence appears in multiple places).

3. Verbose descriptions: Some instructions could be more concise while maintaining their meaning.

4. Example formatting: The module responsibilities sections could be condensed.

5. Process steps: These could be more bullet-pointed rather than containing full sentences.
</think>

The token count is a valid concern for custom instructions, as they consume part of your available context window.

If I were to suggest slimming it down while preserving the essential guidance, I would:

1. **Consolidate Redundant Points**:
   - Several architectural adherence principles appear in multiple sections 
   - The "Feature Development Restriction" and "Change Scope Limitation" cover similar territory

2. **Simplify Project Structure**:
   - Remove the directory tree if you're working in an established project where structure is already visible
   - Or replace with a more condensed version showing just main directories

3. **Condense Module Responsibilities**:
   - Convert the detailed descriptions to bullet-point lists with fewer examples
   - Focus on boundaries rather than exhaustive responsibilities

4. **Streamline Implementation Process**:
   - Convert to shorter bullet points rather than full sentences
   - Remove obvious steps that any senior developer would know

5. **Remove Formatting Examples**:
   - Remove the code block examples if they're not essential

The most token-efficient approach would be keeping only the "Agent Operational Rules" and "Design Guidelines" sections with condensed bullet points, as these contain the core principles that govern decision-making.

---

_**User**_

make an example .md formatted file in this token-efficient manner

---

_**Assistant**_

<think>
I'll create a token-efficient version of the guidelines as a Markdown file. I'll focus on preserving the essential rules while making it more concise by:

1. Using shorter bullet points
2. Consolidating redundant information
3. Removing unnecessary details
4. Keeping only the most critical guidance
5. Using a more compact formatting structure

I'll create this as a new .md file that maintains the core principles but is more token-efficient.
</think>

I'll create a token-efficient version of the guidelines as a Markdown file:

---

_****_

```diff
- 
+ # Project Guidelines
+ 
+ ## Core Principles
+ 
+ ### Architectural Integrity
+ - **No New Features** unless explicitly requested
+ - Maintain established module boundaries
+ - Follow existing design patterns
+ - Use existing components/services
+ - Report inconsistencies rather than fixing without approval
+ 
+ ### Implementation Rules
+ - Focus on specific tasks requested
+ - Verify code against architecture before submitting
+ - Recommend options when uncertain, don't make assumptions
+ - Keep changes reversible and minimal
+ 
+ ## Module Boundaries
+ 
+ | Module | Responsibility | Constraints |
+ |--------|----------------|-------------|
+ | Components | UI presentation | No business logic |
+ | Services | Business logic | State management, API interfacing |
+ | Utils | Pure utility functions | No side effects, no state |
+ | Pages | Component composition | Route management |
+ 
+ ## Implementation Workflow
+ 
+ 1. **Analyze**: Understand existing code and patterns
+ 2. **Plan**: Identify minimal changes needed
+ 3. **Implement**: Follow established patterns
+ 4. **Verify**: Ensure compliance with guidelines
+ 
+ ## Terminal Usage
+ - Use Git Bash syntax for commands
+ - Break large changes into smaller commits
+ - Create descriptive commit messages 
```

---

_****_



I've created a token-efficient version of the guidelines in Markdown format. This version:

1. **Preserves core principles** while reducing verbosity
2. **Uses a table format** for module boundaries to efficiently convey relationships
3. **Numbers key workflow steps** to maintain process clarity
4. **Eliminates redundant sections** like personality instructions that overlap with core principles
5. **Removes extensive examples** but keeps critical constraints

The file is approximately 70% smaller than the original while maintaining the essential guidance. The tabular format for module boundaries is particularly efficient at conveying the separation of concerns without lengthy descriptions.

Would you like me to make any adjustments to this condensed version?

---

_**User**_

project-root/
├── backend/                          # Phoenix/Elixir backend
│   ├── config/                       # Environment-specific configuration (dev, test, prod)
│   │   ├── config.exs
│   │   ├── dev.exs
│   │   └── prod.exs
│   ├── lib/                          # Application source code
│   │   └── word_match_bot/           # Main application namespace
│   │       ├── application.ex        # Application startup and supervision trees
│   │       ├── repo.ex               # Ecto repository for database access
│   │       ├── game/                 # Domain logic for game sessions & event sourcing
│   │       │   ├── game_session.ex   # Game session management (GenServers, event handling)
│   │       │   ├── command_handler.ex# Commands processing (e.g. "RegisterTeam", "SubmitGuess")
│   │       │   └── event.ex          # Immutable events representing state changes
│   │       ├── team/                 # Domain logic for team management
│   │       │   ├── team.ex           # Team aggregates and operations
│   │       │   └── projection.ex     # Read model projections for team stats
│   │       └── user/                 # Domain logic for user management and ratings
│   │           ├── user.ex
│   │           └── rating.ex
│   ├── priv/                         # Static assets, database migrations, seeds, etc.
│   │   └── repo/
│   │       ├── migrations/
│   │       └── seeds.exs
│   └── test/                         # Test suite for backend components
│       └── ... 
├── frontend/                         # Python-based frontend
│   ├── app/                          # Main application source code
│   │   ├── __init__.py
│   │   ├── main.py                   # Application entry point
│   │   ├── api_client.py             # REST/WebSocket client to interact with Phoenix backend
│   │   ├── views/                    # User interface components
│   │   │   ├── templates/            # HTML templates (if using Flask/Django)
│   │   │   │   └── index.html
│   │   │   └── static/               # Static assets (CSS, JS, images)
│   │   │       ├── css/
│   │   │       ├── js/
│   │   │       └── images/
│   │   └── replays/                  # Modules for replay visualization & analytics
│   │       └── visualization.py    # e.g. using matplotlib or Plotly to render game replays
│   ├── tests/                        # Python test suite
│   │   └── test_app.py
│   └── requirements.txt              # Python dependencies
├── docs/                             # Project documentation and design documents
│   ├── README.md
│   ├── README-full.md
│   ├── MODES.md
│   ├── gamemoderules.md
│   └── modearchitecture.md
├── .env                              # Environment variables (database, Redis, etc.)
├── docker-compose.yml                # Orchestration for dependencies (PostgreSQL, Redis, etc.)
├── Makefile                          # Build and deployment tasks
└── package.json                      # (Optional) Node dependencies (if used for tooling/Discord bot)


the above is my intended project structure. do you suggest any revisions to the module boundaries section

---

_**Assistant**_

<think>
The user has shared their intended project structure for a Word Match game application, which appears to be using Phoenix/Elixir for the backend and Python for the frontend. They're asking if I should suggest any revisions to the module boundaries section in the project-guidelines.md file we created earlier.

Looking at the current module boundaries section:

```
## Module Boundaries

| Module | Responsibility | Constraints |
|--------|----------------|-------------|
| Components | UI presentation | No business logic |
| Services | Business logic | State management, API interfacing |
| Utils | Pure utility functions | No side effects, no state |
| Pages | Component composition | Route management |
```

These module boundaries seem to be more aligned with a JavaScript/React frontend application rather than the Phoenix/Elixir backend and Python frontend structure the user has shown.

I should revise the module boundaries to better match their actual project structure, which includes:

1. Backend (Phoenix/Elixir):
   - Application structure
   - Game domain logic
   - Team domain logic
   - User domain logic
   - Repository layer

2. Frontend (Python):
   - API client
   - Views (templates, static assets)
   - Replays (visualization)

I'll update the module boundaries section to reflect this structure while keeping it token-efficient.
</think>

Based on your project structure, I'd revise the Module Boundaries section to better reflect your Phoenix/Elixir backend and Python frontend architecture:

---

_****_

```diff
  | Module | Responsibility | Constraints |
  |--------|----------------|-------------|
- | Components | UI presentation | No business logic |
- | Services | Business logic | State management, API interfacing |
- | Utils | Pure utility functions | No side effects, no state |
- | Pages | Component composition | Route management |
+ | Backend/Game | Game session logic, event sourcing | Follow CQRS pattern, immutable events |
+ | Backend/Team | Team management, scoring | Maintain separation from game mechanics |
+ | Backend/User | User authentication, ratings | No game-specific logic |
+ | Frontend/API | Backend communication | No business logic, simple pass-through |
+ | Frontend/Views | UI presentation | No direct backend calls, use API client |
+ | Frontend/Replays | Visualization, analytics | Read-only, no game state modification |
  
  ## Implementation Workflow
```

---

_****_



I've updated the Module Boundaries section to align with your actual project structure. The revised version:

1. **Reflects your architecture**: Now properly shows the separation between Phoenix backend and Python frontend components

2. **Preserves domain boundaries**: Maintains clear separation between game, team, and user domains in the backend

3. **Enforces communication patterns**: 
   - Frontend views must use API client rather than direct backend calls
   - Backend follows CQRS pattern with immutable events

4. **Defines constraints**: Each module has clear constraints that prevent responsibility drift

5. **Matches your directory structure**: Directly aligns with the folders you've outlined in your project tree

This approach provides better guidance for your specific architecture while maintaining the token-efficient format. The table structure makes the boundaries and constraints visually clear and easy to reference.

---

_**User**_

include information that the frontend is actually a discord bot and needs to always be built to communicate through the discord library

---

_**Assistant**_

<think>
I need to update the project guidelines to clarify that the frontend is actually a Discord bot and needs to communicate through the Discord library. I should modify the Module Boundaries section to reflect this important architectural constraint.

The key points to add:
1. Update Frontend/API to mention Discord communication
2. Clarify that Frontend/Views are Discord-specific interfaces
3. Add a constraint about using the Discord library for all user interactions

I'll keep the update token-efficient while adding this critical information.

---

_****_



---

_****_



Let me try that edit again with a more specific approach:

---

_****_

```diff
  | Backend/Team | Team management, scoring | Maintain separation from game mechanics |
  | Backend/User | User authentication, ratings | No game-specific logic |
- | Frontend/API | Backend communication | No business logic, simple pass-through |
- | Frontend/Views | UI presentation | No direct backend calls, use API client |
- | Frontend/Replays | Visualization, analytics | Read-only, no game state modification |
+ | Frontend/API | Backend & Discord communication | Must use Discord.py library for all user interactions |
+ | Frontend/Views | Discord message formatting | Follow Discord message structure and limitations |
+ | Frontend/Replays | Visualization within Discord | Use Discord-compatible formats (embeds, attachments) |
  
  ## Implementation Workflow
```

---

_****_



I've updated the Module Boundaries section to accurately reflect that your frontend is a Discord bot. The key changes include:

1. **Frontend/API**: Now specifies that it handles both backend communication and Discord interactions, with the constraint that it must use the Discord.py library for all user interactions.

2. **Frontend/Views**: Changed from general UI presentation to Discord-specific message formatting, with constraints that respect Discord's message structure and limitations.

3. **Frontend/Replays**: Updated to clarify that visualizations must work within Discord's capabilities, using appropriate formats like embeds and attachments.

These updates ensure that anyone working on the project understands the critical architectural requirement that all user interaction must happen through Discord's interfaces and API constraints. This will help prevent development of features that wouldn't be compatible with the Discord bot implementation.

---

_**User**_

i've changed my mind: the project is going to be entirely in elixir/phoenix with no python involvement with the following file structure:

project-root/
├── config/                          # Environment-specific configurations
│   ├── config.exs                   # General configuration (including Ecto settings)
│   ├── dev.exs                      # Development config (with DB credentials)
│   ├── prod.exs                     # Production config
│   └── test.exs                     # Test environment config
├── lib/
│   └── game_bot/                    # Main application namespace
│       ├── application.ex         # Application startup and supervision tree
│       ├── bot/                   # Discord bot integration (using Nostrum or similar)
│       │   ├── dispatcher.ex      # Routes incoming Discord events
│       │   ├── command_handler.ex # Processes Discord commands
│       │   └── listener.ex        # Listens to Discord events
│       ├── domain/                # Core game domain logic (DDD, Event Sourcing)
│       │   ├── game_modes/        # Game modes implementations
│       │   │   ├── base_mode.ex
│       │   │   ├── two_player_mode.ex
│       │   │   ├── knockout_mode.ex
│       │   │   ├── race_mode.ex
│       │   │   ├── golf_race_mode.ex
│       │   │   └── longform_mode.ex
│       │   ├── command.ex         # Game command definitions
│       │   ├── event.ex           # Immutable event definitions (for event sourcing)
│       │   └── projection.ex      # Read model projections (stats, history)
│       ├── infrastructure/        # External integrations and persistence
│       │   ├── repo.ex            # Ecto repository (database access)
│       │   ├── postgres/          # Dedicated PostgreSQL layer
│       │   │   ├── models/        # Ecto schemas (GameSession, Team, User, etc.)
│       │   │   ├── queries.ex     # Query modules to encapsulate DB interactions
│       │   │   └── migrations/    # (Optional) Additional migration scripts or helpers
│       │   └── cache.ex           # Caching layer (e.g. ETS)
│       └── web/                   # Optional: Phoenix web interface & channels
│           ├── endpoint.ex        # Phoenix endpoint definition
│           ├── channels/          # Real-time channels
│           ├── controllers/       # Web controllers for APIs (e.g. game replays)
│           ├── views/             # Rendering views/templates
│           └── templates/         # HTML templates
├── priv/
│   ├── repo/                        # Database-related files
│   │   ├── migrations/             # Ecto migrations (for creating tables, etc.)
│   │   └── seeds.exs               # Database seeding script
│   └── static/                      # Static assets (if using a web UI)
├── test/                            # Test suite for the project
│   ├── bot/                         # Tests for Discord bot functionality
│   ├── domain/                      # Tests for game domain logic
│   ├── infrastructure/              # Tests for DB access & Postgres integration
│   └── web/                         # Tests for web controllers and views (if applicable)
├── mix.exs                          # Mix project file (dependencies, tasks, etc.)
├── mix.lock                         # Dependency lock file
└── README.md                        # Project overview and documentation



update the guidelines accordingly

---

_**Assistant**_



---



---


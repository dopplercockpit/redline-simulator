from pathlib import Path

content = """# CANONICAL_ARCHITECTURE.md

## Purpose

This document defines the **target architecture** for Redline Simulator Engine (RSE). It is the authoritative design standard for future development. It describes **what the application must become**, not a snapshot of legacy implementation details, transitional shortcuts, or prototype-era compromises.

All future code, scenes, systems, content pipelines, and integrations should converge toward this architecture.

---

## 1. Canonical Product Definition

Redline Simulator Engine (RSE) is a **deterministic, turn-based educational simulation platform** for business decision-making.

It is designed to teach players how operational choices, financial mechanics, contracts, risk, governance, and strategic tradeoffs interact over time. The engine must support multiple industry skins while preserving a stable core simulation model.

The product consists of:

- a **simulation core** that owns state progression and business logic,
- a **content layer** that defines scenarios, missions, domain data, contracts, news, and educational materials,
- a **presentation layer** that renders the world through Godot scenes, panels, interactions, and guided learning moments,
- and an optional **AI augmentation layer** that enriches explanation, narrative, and coaching without ever becoming the source of simulation truth.

---

## 2. Core Design Principles

### 2.1 Engine First
The engine owns simulation truth. Scenes, panels, and UI are clients of the engine, not alternate sources of logic.

### 2.2 Deterministic by Default
Given the same seed, scenario definition, player actions, and ruleset, the engine must produce the same outcomes.

### 2.3 Data-Driven Content
Scenarios, missions, events, contracts, compendium content, and balance parameters must be externalized into structured content files whenever practical.

### 2.4 Mutation Through Controlled Boundaries
All state mutation must pass through explicit orchestration and validation layers. No scene or UI element may directly mutate authoritative simulation state.

### 2.5 Separation of Concerns
Simulation, accounting, progression, telemetry, UI rendering, and AI augmentation must remain modular and replaceable.

### 2.6 Explainability
The system must be able to explain why outcomes changed. Financial and operational consequences should be inspectable through reports, logs, and teaching overlays.

### 2.7 Industry-Skinnable Core
The engine must support multiple industry modules or skins. Industry-specific terminology and KPIs should be layered on top of shared core mechanics rather than hard-coded into the engine.

---

## 3. Canonical Runtime Layers

The application is divided into five architectural layers:

1. **Core Engine Layer**
2. **Domain and State Layer**
3. **Content Layer**
4. **Presentation Layer**
5. **AI and External Services Layer**

### 3.1 Core Engine Layer
The core engine layer is responsible for orchestration, turn progression, validation, scheduling, mutation routing, event processing, and save/load lifecycle coordination.

### 3.2 Domain and State Layer
This layer contains the authoritative business state, progression state, accounting state, contracts state, and any derived metrics needed for simulation.

### 3.3 Content Layer
This layer defines scenarios, missions, events, market conditions, contract templates, educational prompts, compendium entries, and narrative payloads.

### 3.4 Presentation Layer
This layer renders the simulation to the player using Godot scenes, UI panels, navigation, dialogue, and interactions. It must remain thin and reactive.

### 3.5 AI and External Services Layer
This layer may provide coaching, natural language augmentation, dynamic copy generation, or scoring commentary. It is optional and non-authoritative.

---

## 4. Canonical Runtime Ownership

### 4.1 Authoritative Runtime Systems

The runtime must be centered on a stable set of globally available engine services.

#### RSE
The top-level engine façade. It boots the simulation, initializes deterministic systems, loads scenario packages, exposes high-level commands, and coordinates major runtime systems.

#### GameManager
The application orchestrator for scenario lifecycle, weekly turn advancement, month-end flow, report timing, and cross-system coordination.

#### DecisionResolver
The single authoritative mutation gateway for player decisions and simulation-driven business actions. All business mutations must be validated and applied through this layer.

#### LoopSystem
The progression system for turn count, calendar advancement, unlocks, points, audit pressure, inbox state, and meta-game progression.

#### MissionManager
The mission, challenge, quiz, and learning progression manager. It owns mission lifecycle, mission gating, evaluation hooks, and reward application.

#### Telemetry
The event logging and analytics service. It records player behavior, educational activity, scenario progression, and system events without becoming a gameplay dependency.

### 4.2 Authoritative State Objects

The simulation must maintain distinct authoritative state models.

#### Simulation State
The full operational and financial business state for the current run.

#### Loop State
The current progression, unlock, point, risk, inbox, and player-journey state.

#### Ledger State
The general ledger, trial balance, transaction history, statement artifacts, close flags, and accounting metadata.

#### Content State
Loaded scenario metadata, mission metadata, dynamic content references, and runtime content bindings.

---

## 5. Canonical State Model

### 5.1 Simulation State
Simulation state must capture the business as a living system. It should include, at minimum:

- cash and liquidity
- revenue and expense structures
- product/service capacity
- demand state
- resource allocation
- contracts and counterparties
- operational risk factors
- KPI accumulators
- scenario modifiers
- economic and regulatory environment hooks

The exact domain fields may differ by industry module, but the architecture must preserve a stable interface for calculation and reporting.

### 5.2 Loop State
Loop state should include:

- current turn
- current week, month, quarter, year
- audit pressure or equivalent governance pressure
- points or learning score
- unlock progression
- inbox/message queue
- triggered events
- mission status
- player flags and memory markers

### 5.3 Ledger State
Ledger state must include:

- chart of accounts
- journal entries
- trial balance
- statement mappings
- reporting periods
- month-close and year-close markers
- retained earnings and close metadata
- accounting policy flags where needed by scenario logic

---

## 6. Canonical Time Model

The engine must use a layered time model:

- **Player interaction grain:** weekly turns
- **Operational simulation grain:** sub-week or daily internal calculations when needed
- **Reporting grain:** month-end, quarter-end, and year-end closes

### 6.1 Weekly Turns
One submitted turn represents one business week. The player takes decisions, reviews information, and advances the simulation.

### 6.2 Month-End Close
Every fourth weekly turn triggers month-end close behavior. Month-end is the canonical reporting checkpoint for missions, reporting packages, and learning milestones.

### 6.3 Quarter-End and Year-End
Quarterly and annual closes must enable deeper evaluations, governance consequences, strategic milestones, and advanced financial mechanics.

---

## 7. Canonical Decision Architecture

### 7.1 Decision Entry
All player actions that impact business state must be represented as explicit decision intents or equivalent structured commands.

### 7.2 Decision Validation
Before mutation, each decision must be validated for:

- schema integrity
- action availability
- unlock requirements
- business rule consistency
- budget/resource constraints
- timing constraints
- scenario restrictions

### 7.3 Decision Resolution
DecisionResolver must:

- validate the intent,
- apply permitted mutations,
- trigger dependent recalculations,
- post accounting impacts,
- emit observable events,
- and generate traceable change records.

### 7.4 No Direct UI Mutation
No scene, panel, hotspot, dialogue script, or quiz UI may directly write to authoritative business state.

---

## 8. Canonical Finance Architecture

### 8.1 Finance as a Distinct Subsystem
Finance must be implemented as a dedicated subsystem that converts operational activity and decisions into accounting outcomes, KPIs, and reporting artifacts.

### 8.2 Target Model: Ledger-Backed Finance
The target state is **ledger-backed simulation finance**.

The engine may use intermediate operational calculations to derive business activity, but authoritative financial reporting must come from the ledger and trial balance rather than manually maintained report totals.

### 8.3 Canonical Finance Flow
The canonical flow is:

1. Operational activity is calculated.
2. Financial consequences are translated into accounting events.
3. Accounting events are posted as journal entries.
4. The ledger updates the trial balance.
5. Financial statements are generated from the trial balance.
6. KPI layers and dashboards consume statement outputs and selected operational metrics.

### 8.4 Required Financial Outputs
The canonical finance subsystem must support:

- income statement
- balance sheet
- cash flow statement
- trial balance
- journal transaction inspection
- KPI reporting
- period-over-period comparison
- scenario-sensitive explanatory notes

### 8.5 Accounting Principles
The accounting architecture must support:

- double-entry integrity
- period close controls
- retained earnings treatment
- configurable chart of accounts
- domain-specific posting rules
- extensible accounting policy behavior where needed

### 8.6 Domain Agnosticism
The finance engine must support multiple business models without rewriting the accounting layer. Domain modules may define specific metrics and posting rules, but the underlying ledger framework must remain stable.

---

## 9. Canonical Domain Architecture

### 9.1 Domain Modules
Each industry or educational variant must be implemented as a domain module or skin that plugs into the shared engine.

A domain module may define:

- vocabulary and labels
- scenario content
- KPIs
- event catalogs
- contract types
- operational drivers
- educational framing
- report presentation rules

### 9.2 Domain Boundary
Domain modules may extend rules, but they must not bypass the core engine’s mutation, accounting, or progression boundaries.

### 9.3 Shared Core Mechanics
The engine core should preserve reusable abstractions for:

- capacity
- demand
- pricing
- cost structures
- liquidity
- contracts
- risk and disruption
- governance pressure
- strategic investment
- learning progression

---

## 10. Canonical Mission and Learning Architecture

### 10.1 Missions as Structured Learning Units
Missions are the primary guided-learning vehicle in the simulation. A mission may involve operational decisions, financial review, communication tasks, board evaluation, or quiz assessment.

### 10.2 Mission Lifecycle
Each mission should support:

- trigger conditions
- prerequisites
- inbox/message delivery
- mission briefing
- player action requirements
- evaluation logic
- reward and penalty logic
- archival and review

### 10.3 Boardroom and Assessment Layer
Boardroom, executive review, audit review, and equivalent checkpoints are canonical assessment mechanisms. They should test comprehension, not just clicking compliance.

### 10.4 Educational Traceability
The system should be able to connect outcomes back to the player’s decisions and explain the relevant business concepts.

---

## 11. Canonical Event Architecture

### 11.1 Event Types
The engine must support event classes such as:

- macroeconomic shifts
- demand shocks
- supplier disruptions
- contract changes
- regulatory actions
- operational failures
- governance findings
- opportunity events
- narrative or reputational events

### 11.2 Event Processing
Events must be data-driven where possible and processed through the core engine. Event effects must be traceable and reversible only through deliberate game systems, not ad hoc script patches.

### 11.3 Event Scope
An event may affect:

- simulation state
- accounting state
- mission availability
- unlocks
- inbox content
- AI guidance
- educational prompts

---

## 12. Canonical Contract Architecture

### 12.1 Contracts as First-Class Objects
Contracts must be represented as structured, inspectable entities rather than pure flavor text.

### 12.2 Required Contract Features
Contracts should support:

- counterparties
- commercial terms
- service or product scope
- volume or usage commitments
- pricing rules
- penalties
- timing and lead constraints
- termination logic
- amendment logic
- scenario-linked clauses

### 12.3 Contract Presentation
Contracts may be rendered as document-style panels, but underlying terms must remain machine-readable so they can influence simulation behavior.

---

## 13. Canonical Content Architecture

### 13.1 Externalized Content
The following content should be externalized into files or packages:

- scenarios
- missions
- event definitions
- contract templates
- compendium entries
- boardroom prompts
- inbox/news content
- COA and posting maps
- domain labels
- tutorial content

### 13.2 Content Versioning
Content packages must be versionable and migration-friendly. Scenario schemas should evolve through documented versions rather than silent breakage.

### 13.3 Content Loading
The engine must load content through formal loaders and validators rather than raw scene-level file assumptions.

---

## 14. Canonical Presentation Architecture

### 14.1 UI as a Client
The presentation layer is a client of the engine. It does not own simulation truth.

### 14.2 Scene Responsibilities
Scenes should be responsible for:

- world navigation
- displaying panels
- routing user interactions
- visual affordances
- pacing and atmosphere
- invoking engine actions through approved interfaces

### 14.3 Panel Responsibilities
Panels should display:

- financial reports
- missions
- contracts
- compendium content
- news
- inbox items
- analysis prompts
- educational hints

Panels may request actions from engine services but must not contain embedded business logic.

### 14.4 Interaction Grammar
Interactions should converge on a reusable action grammar such as:

- inspect
- use
- discuss
- decide
- review
- authorize
- investigate

The exact labels may vary by domain, but the interaction system should be systematic rather than bespoke for every object.

---

## 15. Canonical Save/Load Architecture

### 15.1 Save Authority
Save and load operations must be owned by engine-level services, not scenes.

### 15.2 Save Scope
A save file must contain, or reconstruct from content references:

- simulation state
- loop state
- ledger state
- mission state
- event history
- RNG seed state
- scenario identity and schema version
- player progression markers

### 15.3 Versioning and Migration
All persistent data must support schema versioning and migration. Breaking state without migration is not acceptable.

---

## 16. Canonical Telemetry Architecture

### 16.1 Purpose
Telemetry exists to support educational evaluation, tuning, debugging, and instructional insight.

### 16.2 Telemetry Events
Telemetry should capture events such as:

- scenario load
- panel open and close
- decision submission
- week advance
- month close
- mission completion
- quiz performance
- hint usage
- player text submissions
- session timing

### 16.3 Constraints
Telemetry must not become a runtime dependency for core simulation progression. Logging failure must not break gameplay.

---

## 17. Canonical AI Architecture

### 17.1 AI as Augmentation, Never Authority
AI may assist with:

- narrative generation
- contract language decoration
- coaching and nudges
- explanation
- post-decision analysis
- personalized educational commentary
- dynamic news flavor text

AI must not become the source of:

- authoritative state mutation
- accounting truth
- scoring truth
- deterministic event resolution
- canonical simulation outcomes

### 17.2 Structured Interfaces
Any AI integration must exchange structured payloads with the engine and operate within explicit schemas.

### 17.3 Graceful Degradation
The simulation must remain fully playable without AI services.

---

## 18. Canonical Signals and Observability

### 18.1 Signal-Driven UI
Engine systems should emit clear signals for state changes, turn advancement, month-end, mission updates, report generation, and errors.

### 18.2 Explainability Hooks
The architecture should support traceable “why did this happen?” inspection paths for finance, mission, and event outcomes.

### 18.3 Debug Support
Developer-facing visibility tools should be available for:

- current scenario state
- pending events
- ledger and trial balance
- mission status
- turn counters
- unlock state
- recent decision log

---

## 19. Canonical Security and Integrity Constraints

### 19.1 Trust Boundaries
UI, AI services, and external connectors are not trusted to define simulation truth. Only engine-authorized layers may mutate core state.

### 19.2 Validation
All imported content, save data, and external payloads must be validated before use.

### 19.3 Reproducibility
Scenario runs should be reproducible for teaching, debugging, and evaluation purposes whenever deterministic mode is enabled.

---

## 20. Canonical File and System Roles

The repository should eventually reflect the following conceptual roles:

### Core Engine
- orchestration
- decision resolution
- turn progression
- state lifecycle
- event scheduling

### Finance and Ledger
- operational finance calculation
- accounting translation
- journal posting
- trial balance maintenance
- statement generation

### Missions and Learning
- mission definitions
- mission lifecycle
- quiz and assessment flow
- reward and penalty application

### Content
- scenario packages
- events
- contracts
- compendium
- news
- reporting templates
- instructional copy

### UI
- world scenes
- panels
- interaction controllers
- visual shell

### Integrations
- telemetry outputs
- optional AI services
- optional external content or scoring endpoints

---

## 21. Canonical Development Rules

All future work must follow these rules:

1. No direct scene mutation of authoritative business state.
2. No domain-specific shortcuts that bypass the engine boundary.
3. No manual report totals where ledger-derived reporting is required.
4. No new content formats without schema definition and validation.
5. No AI dependency for core playability.
6. No save format changes without migration strategy.
7. No hidden business logic in UI scripts.
8. No system may become authoritative by accident; ownership must be explicit.

---

## 22. Canonical Roadmap Direction

The target architecture should evolve toward the following end state:

### Phase 1: Stable Engine Core
A robust engine boundary with deterministic turn progression, structured decisions, save/load, mission flow, and baseline ledger-backed reporting.

### Phase 2: Rich Domain Modules
Multiple scenario and industry packages plugged into the same engine with reusable finance, contracts, events, and teaching systems.

### Phase 3: Deep Reporting and Explainability
Richer ledger detail, better drill-down, governance reporting, explanatory overlays, and educational analytics.

### Phase 4: Scalable Instructional Platform
Admin tooling, classroom controls, comparative player analytics, modular content authoring, and AI-assisted coaching layered safely on top of the deterministic core.

---

## 23. Final Canonical Statement

Redline Simulator Engine must be built as a **modular, deterministic, ledger-backed, content-driven educational simulation platform** in which:

- the engine owns truth,
- the ledger owns financial reporting,
- the resolver owns mutation,
- the loop owns progression,
- the content layer defines scenarios,
- the UI renders and dispatches,
- and AI only augments, never governs.

Any implementation detail that conflicts with this document should be treated as technical debt or transitional legacy rather than architecture.
"""

path = Path("/mnt/data/CANONICAL_ARCHITECTURE.md")
path.write_text(content, encoding="utf-8")
print(f"Wrote {path}")

# AI Life Partner — AGENTS.md

## Development Instructions for AI Coding Agents

---

## 1. Purpose

This document defines the rules that AI coding agents, including Codex, must follow when modifying the AI Life Partner repository.

AI Life Partner is not an AI-centered application.

It is a Human First Life Operating System designed to help people think, choose, act, reflect, and grow.

All generated code, tests, architecture decisions, and documentation must remain consistent with the principles defined in this repository.

---

## 2. Core Statement

> **Human is the center.**
>
> **AI is the partner.**
>
> **Growth is the purpose.**

AI Life Partner exists to help people become better able to think for themselves.

The system must not replace Human judgment.

The system must support Human thinking, Human choice, Human action, Human reflection, and Human independence.

---

## 3. Required Reference Documents

Before implementing or modifying important functionality, review the relevant documents.

### Foundation

- `FOUNDATION/00_MANIFESTO.md`
- `FOUNDATION/01_PROJECT_CHARTER.md`
- `FOUNDATION/02_AI_PRINCIPLES.md`
- `FOUNDATION/03_PRODUCT_PHILOSOPHY.md`
- `FOUNDATION/04_LIFE_OPERATING_SYSTEM.md`
- `FOUNDATION/05_HUMAN_PRINCIPLES.md`

### Product and System Design

- `docs/00_ProjectOverview.md`
- `docs/01_UserExperience.md`
- `docs/02_Requirements.md`
- `docs/03_Functions.md`
- `docs/04_DataModel.md`
- `docs/05_SystemArchitecture.md`

When code and documentation conflict, do not silently choose one.

Report the inconsistency and propose an aligned solution.

---

## 4. Human First

Human is always the primary actor.

The system must allow the Human to:

- understand the current situation
- review information used by AI
- consider multiple options
- modify an AI proposal
- reject an AI proposal
- postpone a decision
- make the final decision
- review and correct stored information
- delete stored information
- control sharing
- revoke previously granted permissions

Do not implement features that make AI the final decision-maker.

---

## 5. AI Is Outside the Human

AI is not part of the Human model.

AI interacts with the Human through Dialogue.

The Human owns:

- Identity
- Life
- Relationships
- Thinking
- Life Projects
- Purpose
- Goals
- Plans
- Actions
- Journey
- Reflection
- Insight
- Growth

AI may support the interpretation of these concepts, but it must not redefine them without Human confirmation.

AI-generated assumptions must remain distinguishable from Human-confirmed facts.

---

## 6. AI Proposal Rules

An AI proposal must never be treated as a confirmed decision by default.

Important proposals should support the following states:

- `Proposed`
- `Under Consideration`
- `Modified`
- `Accepted`
- `Deferred`
- `Rejected`

The Human must perform the final confirmation.

Where appropriate, an AI proposal should include:

1. Current situation
2. Proposed option
3. Reason
4. Alternative options
5. Uncertainty or caution
6. Request for Human confirmation

Do not automatically add, change, or delete important schedules, goals, plans, actions, permissions, or shared data based only on AI output.

---

## 7. Life Project Engine

Life Project Engine is the core domain of AI Life Partner.

It supports the following cycle:

    Dialogue
      ↓
    Purpose
      ↓
    Goal
      ↓
    Current Status
      ↓
    Planning
      ↓
    Human Decision
      ↓
    Action
      ↓
    Journey
      ↓
    Reflection
      ↓
    Insight
      ↓
    Growth
      ↓
    Next Dialogue

Life Project Engine is not merely a task-management engine.

It exists to support the Human growth cycle.

Domain features such as Training and Learning must build upon this common structure rather than creating isolated systems.

---

## 8. Journey and Growth

Do not reduce Journey to a simple activity log.

Journey represents the path a Human has walked.

It may include:

- actions
- results
- changes of plan
- pauses
- retries
- difficulties
- feelings
- discoveries
- advice received
- decisions made
- events that prevented an intended action
- changes in Purpose or Goal

Do not label an incomplete or changed plan as failure by default.

Growth must not be inferred from a single numerical result.

Growth may include:

- improved understanding
- continued effort
- formation of habits
- better judgment
- ability to revise plans
- ability to ask for help
- ability to reflect
- ability to make independent decisions
- increased independence

Journey and Growth are not separate, unrelated concepts.

Growth must be grounded in the Human's Journey.

---

## 9. Thinking and Dialogue

AI Life Partner must not only provide answers.

Where appropriate, it should help the Human think by:

- clarifying the situation
- asking focused questions
- identifying assumptions
- presenting alternatives
- explaining trade-offs
- supporting reflection
- helping the Human express a decision
- helping the Human recognize uncertainty
- connecting previous experiences to the current situation

Do not ask unnecessary questions.

Do not turn every interaction into a long dialogue.

Support should be proportional to the Human's request, situation, age, preferences, and available time.

The purpose of Dialogue is not to prolong engagement.

The purpose is to help the Human think more clearly.

---

## 10. Family and Sharing

Family features are optional.

AI Life Partner must work fully for a single individual without requiring family participation.

Every family member must have:

- an independent account
- an independent Human identity
- independent privacy settings
- independent sharing permissions

Membership in the same family must not automatically grant access to all data.

Sharing must be:

- optional
- explicit
- understandable
- reversible
- granular
- based on the Human's consent
- private by default

Examples of separate sharing units include:

- Life Project summary
- Purpose
- Goals
- Schedule
- Action plan
- Journey
- Learning records
- Test results
- AI analysis
- Reflection
- AI dialogue
- Health information
- Advice from teachers or trainers

Sensitive information such as Reflection, feelings, health data, and AI dialogue should remain private by default.

A parent or guardian must not automatically gain unrestricted access to a child's data solely because of their role.

Age, legal requirements, safety, maturity, understanding, and the child's dignity must be considered.

Family functionality must support communication and assistance, not surveillance.

---

## 11. Privacy by Default

Private is the default state.

Collect only information needed to provide the requested support.

Humans must be able to:

- view stored data
- correct stored data
- delete stored data
- export stored data where supported
- view AI Memory
- correct AI Memory
- delete AI Memory
- disable AI use of selected information
- control sharing
- revoke consent
- understand why information is being collected
- understand how information is being used

Do not place secrets, API keys, service-role keys, or private credentials in the client application or repository.

Do not include sensitive personal content in ordinary application logs.

Do not use private data for unrelated purposes.

---

## 12. AI Gateway

The Flutter application must not call external AI providers directly.

Use the following structure:

    Flutter Application
      ↓
    Application Service
      ↓
    AI Gateway
      ↓
    AI Provider

The AI Gateway is responsible for:

- protecting API keys
- selecting the AI provider or model
- minimizing context
- applying AI Principles
- applying Human Principles
- validating structured output
- filtering inappropriate output
- recording safe audit metadata
- handling errors and timeouts
- allowing future provider replacement
- preventing unrelated data from being sent
- separating Human-confirmed facts from AI assumptions

Send only the minimum information needed for the current request.

Do not send unrelated family, health, learning, or dialogue data to the AI Provider.

---

## 13. Flutter Architecture

Use a feature-first structure.

Recommended top-level structure:

    lib/
    ├── main.dart
    ├── app/
    ├── core/
    ├── features/
    └── shared/

Feature examples:

    features/
    ├── onboarding/
    ├── home/
    ├── life_projects/
    ├── schedule/
    ├── actions/
    ├── journey/
    ├── reflection/
    ├── dialogue/
    ├── training/
    ├── nutrition/
    ├── sleep/
    ├── learning/
    ├── family/
    └── settings/

Keep the following responsibilities separated:

- UI presentation
- UI state
- application use cases
- domain rules
- repositories
- infrastructure
- external services

Screens and widgets must not directly contain database access logic.

Screens and widgets must not directly call external AI providers.

---

## 14. Repository Pattern

Use repository interfaces between application or domain logic and external data sources.

Preferred flow:

    Screen
      ↓
    Controller / View Model
      ↓
    Use Case
      ↓
    Repository Interface
      ↓
    Repository Implementation
      ↓
    Supabase / Local Storage / External Service

This separation must support:

- testing
- future offline support
- replacement of external services
- separation of domain rules from infrastructure
- clear error handling
- controlled synchronization
- consistent authorization behavior

Do not allow presentation code to depend directly on Supabase response objects.

---

## 15. Domain Independence

Domain models must not directly depend on:

- Flutter widgets
- Supabase response objects
- database row formats
- external AI provider formats
- HTTP response models
- platform-specific APIs

Core concepts such as the following should remain technology-independent:

- Human
- Identity
- Relationship
- Life Project
- Purpose
- Goal
- Plan
- Action
- Journey
- Reflection
- Insight
- Growth
- AI Suggestion
- Human Decision
- Sharing Permission
- Consent

Convert infrastructure data into domain models at repository or mapper boundaries.

---

## 16. Supabase Rules

Use Supabase for the Family MVP data platform unless an approved architecture decision changes this.

Expected components include:

- Supabase Auth
- PostgreSQL
- Row Level Security
- Supabase Storage
- Edge Functions

Row Level Security must be treated as a primary security boundary.

Do not rely only on client-side filtering.

Every table containing Human-owned information must define:

- ownership
- who may read it
- who may create it
- who may update it
- who may delete it
- whether it may be shared
- how consent is represented

Family sharing must use explicit permission data rather than assumptions based only on family membership.

Service-role access must never be exposed to the Flutter client.

---

## 17. UI and UX Rules

The UI must distinguish clearly between:

- Human-confirmed data
- AI proposals
- AI assumptions
- unconfirmed information
- shared information
- private information
- information received from another Human
- information obtained from an external service

AI proposals must not visually appear as confirmed plans.

Humans must be able to understand:

- what will happen
- what data will be saved
- what data will be shared
- who can see it
- whether AI generated or inferred it
- whether the item is confirmed or only proposed
- how to change or reject it

Avoid manipulative UI patterns.

Do not use guilt, fear, urgency, comparison, or excessive alerts to force engagement.

Do not design the application to maximize screen time.

---

## 18. Notifications

Notifications exist to support real-world action, not to increase application usage.

Humans must control:

- notification type
- domain
- frequency
- time
- quiet hours
- whether AI-generated suggestions may trigger notifications
- whether notification text may contain sensitive details

Do not include sensitive details in lock-screen notifications by default.

Do not use messages that blame or shame the Human.

Prefer supportive language such as:

> Your schedule changed today. Would you like to reconsider the remaining plan?

Avoid language such as:

> You have failed to complete today's task.

---

## 19. Family MVP Priority

For the first family release, prioritize a complete Human journey over a large number of features.

The essential flow is:

    Account
      ↓
    Onboarding
      ↓
    Life Project
      ↓
    Purpose and Goal
      ↓
    Plan and Action
      ↓
    Human Decision
      ↓
    Journey
      ↓
    Reflection
      ↓
    AI Dialogue
      ↓
    Next Action

Initial supported domains:

- Training
- Learning
- Meals
- Sleep

Family sharing is optional.

The application must remain fully usable without enabling Family features.

Do not add future domains unless they are necessary for the Family MVP or explicitly approved.

---

## 20. Out of Scope for Initial MVP

Do not implement the following as required MVP features unless explicitly requested:

- social network
- public community
- advanced voice assistant
- smartwatch application
- HealthKit integration
- Health Connect integration
- advanced meal image recognition
- financial management
- travel planning
- full offline synchronization
- autonomous schedule changes
- unrestricted parent monitoring
- mandatory family participation
- large administrative dashboards
- public leaderboards
- competitive ranking between Humans

These features may be reconsidered after validating the Family MVP.

---

## 21. Code Quality

All generated code should:

- be readable
- use clear naming
- avoid unnecessary abstraction
- handle errors explicitly
- include tests for important domain rules
- pass `flutter analyze`
- pass relevant automated tests
- avoid deprecated APIs when practical
- keep files focused in responsibility
- document non-obvious design decisions
- preserve null safety
- avoid unnecessary dependencies
- expose failures clearly rather than silently ignoring them

Do not generate placeholder architecture that is not used.

Do not add dependencies without explaining:

- why they are needed
- what responsibility they serve
- what alternatives were considered
- what maintenance or privacy risk they introduce

---

## 22. Testing Priorities

Prioritize tests for:

- Life Project state changes
- Purpose and Goal relationships
- AI proposal state changes
- Human confirmation
- Human rejection and modification
- Journey creation
- Reflection ownership
- Growth evidence relationships
- family sharing permissions
- private-by-default behavior
- child and guardian boundaries
- consent changes
- repository behavior
- AI structured-output validation
- Row Level Security policies
- prevention of unauthorized access
- separation of AI assumptions and confirmed facts

UI snapshot tests alone are not sufficient.

Important Human First rules must be covered by domain, repository, integration, and security tests.

---

## 23. Error Handling

Errors must be understandable and recoverable where possible.

Do not expose internal server details, credentials, stack traces, or database information to the Human.

When an operation fails:

- explain what could not be completed
- preserve unsaved Human input where practical
- provide a retry option where appropriate
- avoid claiming success
- avoid silently discarding data
- record safe diagnostic information
- distinguish network errors from permission errors and validation errors

AI errors must not cause confirmed Human data to be overwritten.

---

## 24. Change Discipline

Before making a large change:

1. Identify the affected Foundation and docs files.
2. Explain the intended change.
3. Identify possible conflicts with Human First.
4. Identify privacy and sharing impacts.
5. Keep the change as small as practical.
6. Add or update tests.
7. Run analysis and tests.
8. Summarize changed files.
9. Summarize remaining risks.
10. Note any documentation that still requires updating.

Do not rewrite unrelated files.

Do not remove existing documentation or principles without explicit approval.

Do not change the MVP scope silently.

---

## 25. Documentation Updates

When a code change alters architecture, data concepts, user behavior, AI behavior, privacy, sharing, or MVP scope, update the corresponding documentation.

Examples:

- Function changes → `docs/03_Functions.md`
- Data concept changes → `docs/04_DataModel.md`
- Architecture changes → `docs/05_SystemArchitecture.md`
- AI behavior changes → future AI architecture document
- Sharing changes → Requirements, Functions, Architecture, and Security documents
- MVP scope changes → Roadmap and System Architecture
- Human or AI principles changes → relevant `FOUNDATION` documents

Code and documentation must grow together.

Documentation must not describe features that no longer exist without clearly marking them as future plans.

---

## 26. AI Coding Agent Behavior

AI coding agents working on this repository must:

- explain significant assumptions
- avoid inventing requirements
- ask for clarification when a major product decision is unresolved
- keep implementation aligned with approved documents
- avoid expanding scope without approval
- preserve existing Human First behavior
- report incomplete work honestly
- report failed tests honestly
- report security or privacy concerns
- identify when a request conflicts with Foundation principles
- prefer small, reviewable changes
- avoid claiming that code works without running available checks

AI coding agents must not prioritize speed over Human safety, privacy, or project consistency.

---

## 27. Final Review Questions

Before completing any significant task, verify:

- Is Human still the center?
- Does the Human make the final decision?
- Can the Human reject, defer, or correct the result?
- Is AI acting as a partner rather than an authority?
- Does the feature help the Human think?
- Does it preserve the meaning of Journey?
- Is Growth grounded in Journey?
- Is sharing optional and granular?
- Is private data private by default?
- Are children treated as independent Humans with dignity?
- Is family functionality supporting rather than monitoring?
- Is AI context limited to what is necessary?
- Are AI assumptions distinguishable from facts?
- Can the component be tested?
- Are access controls enforced on the server or database side?
- Is the MVP becoming more useful rather than merely larger?
- Does the change remain consistent with the Foundation documents?

If a significant answer is no, revise the implementation before completion.

---

# Closing Statement

AI Life Partner is built to support people, not to control them.

Every line of code must respect the Human's ability to think, choose, walk, reflect, and grow.

AI may organize information.

AI may explain.

AI may ask.

AI may propose.

But the Human decides.

> **Human is the center.**
>
> **AI is the partner.**
>
> **Growth is the purpose.**

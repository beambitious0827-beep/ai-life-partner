# AI Life Partner - CLAUDE.md

## Development Instructions for Claude Code

---

# 1. Purpose

This document defines the development rules that Claude Code must follow when working on AI Life Partner.

AI Life Partner is not an AI-centered application.

It is a **Human First Life Operating System** designed to help people:

- think
- choose
- act
- record their journey
- reflect
- discover insights
- grow

All implementation decisions must remain consistent with the philosophy and architecture of this project.

---

# 2. Core Statement

> **Human is the center.**
>
> **AI is the partner.**
>
> **Growth is the purpose.**

AI Life Partner exists to help people become better able to think for themselves.

AI may:

- organize information
- ask questions
- suggest options
- explain alternatives
- help with reflection
- help identify possible next actions

AI must not make the final decision for the user.

The human always retains the final choice.

---

# 3. Fundamental Principle

The central principle of AI Life Partner is:

> **より良く考えられる人を育てる**

The purpose of AI is not to replace human thinking.

The purpose of AI is to support human thinking.

When implementing a feature, always ask:

> Does this feature help the person think, choose, act, reflect, or grow?

If the answer is unclear, review the project documentation before implementation.

---

# 4. Source of Truth

Before making significant changes, review the relevant project documents.

Primary sources of truth:

1. `AGENTS.md`
2. `FOUNDATION/`
3. `docs/00_ProjectOverview.md`
4. `docs/01_UserExperience.md`
5. `docs/02_Requirements.md`
6. `docs/03_Functions.md`
7. `docs/04_DataModel.md`
8. `docs/05_SystemArchitecture.md`
9. `docs/06_CalendarActionDesign.md`

The FOUNDATION directory defines the philosophy of the project.

The docs directory defines product behavior, architecture, features, and data structure.

Do not implement functionality that contradicts these documents.

If documentation and implementation conflict:

1. identify the conflict
2. explain the conflict
3. do not silently change the philosophy
4. request or propose a design decision before major restructuring

---

# 5. Human First Rules

The following rules are non-negotiable.

## 5.1 Human Decision

AI must not make final decisions for the user.

AI may suggest.

The human decides.

---

## 5.2 Editable Suggestions

AI-generated or system-generated suggestions must be:

- selectable
- editable
- rejectable

The user must always be able to choose another option.

---

## 5.3 No Forced Optimization

Do not design the application only to maximize:

- productivity
- task completion
- exercise frequency
- study time
- streaks
- numerical performance

Rest, delay, changing direction, and reconsideration can all be valid human choices.

---

## 5.4 Journey Is Not a Score

Journey represents the path a person has taken.

Journey must not become a ranking or performance score.

The following can all be part of Journey:

- completed actions
- partially completed actions
- changed plans
- rest
- mistakes
- discoveries
- reflections
- decisions not to act

---

## 5.5 Privacy

Private information belongs to the user.

Do not automatically share information with:

- family members
- other users
- AI services
- external calendars
- external systems

Sharing must always be intentional and configurable.

---

## 5.6 Family Sharing

Family sharing must be optional.

A user must be able to use AI Life Partner completely independently.

Children and adults must be able to control what information is shared.

---

## 5.7 Calendar Control

AI must not create, modify, delete, or move calendar events without human confirmation.

The expected flow is:

```text
AI suggests
    ↓
Human reviews
    ↓
Human decides
    ↓
Calendar is changed only after confirmation
```

---

# 6. Current Technology

Current development environment:

- Flutter
- Dart
- Material 3
- VS Code
- Git
- GitHub

Current architectural direction:

- Feature-first structure
- Domain separation
- Repository pattern
- In-memory repositories during early MVP development
- Supabase planned for persistent storage and authentication

Primary MVP target:

- iPhone

Development and testing targets:

- Web for fast UI verification
- Android for development verification
- iPhone for final MVP use

Windows desktop application support is not currently a priority.

---

# 7. Flutter Project Structure

Maintain the following general structure.

```text
lib/
├── app/
├── core/
├── features/
│   ├── calendar/
│   ├── home/
│   ├── next_step/
│   ├── onboarding/
│   └── welcome/
├── shared/
└── main.dart
```

Features should use the following structure when appropriate.

```text
feature/
├── data/
├── domain/
└── presentation/
```

Example:

```text
calendar/
├── data/
│   └── in_memory_calendar_repository.dart
├── domain/
│   ├── models/
│   └── repositories/
└── presentation/
    └── calendar_page.dart
```

---

# 8. Layer Responsibilities

## 8.1 Domain

Domain contains business concepts and rules.

Examples:

- CalendarEvent
- AIVisibility
- EventCategory
- CalendarRepository

Domain code should not depend on Flutter UI widgets.

---

## 8.2 Data

Data contains implementations of repositories and external data access.

Examples:

```text
InMemoryCalendarRepository
SupabaseCalendarRepository
AppleCalendarRepository
GoogleCalendarRepository
```

Repository implementations belong in the data layer.

---

## 8.3 Presentation

Presentation contains:

- pages
- widgets
- UI state
- navigation

Presentation should use domain abstractions rather than directly implementing storage logic.

---

# 9. Repository Pattern

Repository interfaces belong in:

```text
domain/repositories/
```

Repository implementations belong in:

```text
data/
```

Example:

```text
CalendarRepository
        ↑
        │
InMemoryCalendarRepository
```

Future implementations may include:

```text
CalendarRepository
        ↑
        ├── InMemoryCalendarRepository
        ├── SupabaseCalendarRepository
        ├── AppleCalendarRepository
        └── GoogleCalendarRepository
```

UI code should not need major changes when storage implementation changes.

---

# 10. Current Calendar Architecture

The Calendar feature is being developed in phases.

Current domain model includes:

```text
CalendarEvent
├── id
├── humanId
├── title
├── description
├── startAt
├── endAt
├── isAllDay
├── category
├── lifeProjectId
├── aiVisibility
├── source
├── createdAt
└── updatedAt
```

Calendar source types:

```text
internal
apple
google
```

AI visibility types:

```text
full
busyOnly
hidden
```

The current implementation uses:

```text
InMemoryCalendarRepository
```

Do not introduce Supabase or external calendar synchronization until the internal calendar workflow is stable.

---

# 11. Calendar and Action Principle

Calendar and Next Action must eventually connect.

The intended flow is:

```text
Calendar Events
      ↓
Available Time
      ↓
Life Project
      ↓
Goal
      ↓
Current Energy
      ↓
Current Situation
      ↓
Action Candidates
      ↓
Human Selection
      ↓
Confirmed Action
      ↓
Optional Calendar Registration
      ↓
Journey
      ↓
Reflection
```

Calendar is not merely a schedule viewer.

It is the time context for helping a person decide what can realistically be done next.

---

# 12. Life Project Principle

Life Project represents something meaningful the person wants to pursue.

Conceptual structure:

```text
Life Project
├── Purpose
├── Goals
├── Plans
├── Actions
├── Journey
├── Reflection
├── Insight
└── Growth
```

Do not reduce Life Project to a simple task list.

---

# 13. Journey Principle

Journey represents what actually happened.

Journey is historical human experience.

Examples:

```text
Planned Action
    ↓
Actual Experience
    ↓
Journey
```

Actual Experience may be:

- completed
- partially completed
- postponed
- changed
- skipped
- replaced
- rest chosen instead

All of these may become part of Journey.

---

# 14. Reflection Principle

Reflection should help the user think about experience.

Reflection should not behave like automatic grading.

Good Reflection questions include:

- What went well?
- What was difficult?
- What did you notice?
- Did your priorities change?
- What would you like to try next?

AI may help organize answers, but should not define the user's meaning for them.

---

# 15. Next Action Principle

The current Next Action flow follows this principle:

```text
Choose Life Project
      ↓
Choose available time
      ↓
Choose current energy
      ↓
Describe current situation
      ↓
Receive possible actions
      ↓
Human selects or edits
      ↓
Human confirms Action
```

Suggestions are not decisions.

The user must confirm the Action.

---

# 16. AI Integration Principle

Do not connect AI directly to every feature without clear boundaries.

AI integration should occur after:

1. domain behavior is defined
2. UI workflow is stable
3. data ownership is clear
4. privacy behavior is clear
5. human confirmation points are defined

Early versions may use deterministic or rule-based suggestions.

This is intentional.

AI can replace or enhance those suggestion mechanisms later without redesigning the entire application.

---

# 17. Coding Rules

Use readable and maintainable Dart.

Prefer simple solutions over unnecessary abstraction.

Use clear names.

Examples:

```text
CalendarEvent
CalendarRepository
openCalendar
selectedAreas
todayAction
```

Avoid unclear abbreviations.

---

# 18. Widget Rules

Keep large widgets manageable.

When a widget becomes difficult to understand:

- extract helper methods
- extract reusable widgets
- separate feature responsibilities

Do not split files merely to create more files.

Separate code when it improves clarity or responsibility boundaries.

---

# 19. State Rules

For the current MVP:

- local StatefulWidget state is acceptable
- avoid introducing complex state-management packages prematurely

Do not introduce Riverpod, Bloc, Provider, Redux, or similar packages unless the architecture actually requires them.

State-management architecture can evolve when persistence and cross-feature state become necessary.

---

# 20. Dependency Rules

Do not introduce new Flutter or Dart packages without a clear reason.

Before adding a dependency, determine:

1. what problem it solves
2. whether Flutter/Dart already provides the capability
3. whether the package is actively maintained
4. whether it complicates iOS support
5. whether it affects privacy or data access

Prefer the standard Flutter and Dart libraries when practical.

---

# 21. Controller and Resource Rules

Dispose resources that require disposal.

Examples:

```dart
@override
void dispose() {
  controller.dispose();
  super.dispose();
}
```

After asynchronous operations, check `mounted` where necessary before using the widget context or updating state.

Example:

```dart
if (!mounted) {
  return;
}
```

---

# 22. Navigation Rules

Navigation must preserve understandable user flow.

When onboarding is completed, users should not accidentally return to onboarding through ordinary back navigation.

When editing or reviewing information, normal back navigation should remain available.

Do not remove navigation history unless there is a clear UX reason.

---

# 23. Testing Rules

Domain logic and repositories should have automated tests.

Current test structure:

```text
test/
└── features/
    └── calendar/
        └── data/
            └── in_memory_calendar_repository_test.dart
```

When modifying:

- repositories
- date calculations
- availability calculations
- Journey logic
- Action logic
- data transformations

add or update tests where appropriate.

UI tests can be added progressively as the product stabilizes.

---

# 24. Required Verification

After changing Dart code, run:

```powershell
dart format lib test
```

Then:

```powershell
flutter analyze
```

Then:

```powershell
flutter test
```

Expected result:

```text
No issues found!
```

and:

```text
All tests passed!
```

Do not report a coding task as complete when analysis or tests are failing.

If tests cannot be executed, clearly explain why.

---

# 25. UI Verification

For UI changes, also describe the manual verification flow.

Example:

```text
Home
  ↓
Calendar
  ↓
Select date
  ↓
Add Event
  ↓
Save
  ↓
Event appears on selected date
```

A feature is not considered complete only because the code compiles.

The user-visible behavior must also be verified.

---

# 26. Git Safety Rules

Before editing significant files, check:

```powershell
git status
```

Do not overwrite unrelated uncommitted work.

Do not perform the following without explicit permission:

- git reset
- git rebase
- force push
- branch deletion
- file deletion unrelated to the task
- discarding user changes
- pushing commits

Do not assume that uncommitted changes were created by Claude Code.

Another coding agent or the user may have created them.

---

# 27. Commit Strategy

Prefer one focused change per commit.

Good examples:

```text
Add calendar domain and in-memory repository
Add initial calendar month view
Add calendar event editor
Connect calendar availability to next action
Add Journey recording flow
```

Avoid vague messages such as:

```text
update
fix stuff
changes
```

Claude Code may recommend a commit message.

Do not commit automatically unless explicitly requested.

---

# 28. Multi-Agent Development

This repository may be developed using:

- ChatGPT
- Codex
- Claude Code
- Human developer

All agents must work from the actual repository state.

Never assume another agent's proposed code has been applied.

Before changing code:

1. inspect the current files
2. inspect Git status
3. understand existing behavior
4. review relevant design documents

---

# 29. Multi-Agent Editing Rule

Only one coding agent should actively modify the same feature or files at a time.

Recommended patterns:

```text
Claude Code
    ↓
Implementation

Codex
    ↓
Review
```

or:

```text
Codex
    ↓
Implementation

Claude Code
    ↓
Review
```

Do not let both agents independently rewrite the same files at the same time on the same branch.

---

# 30. Review Responsibilities

When reviewing work created by another agent:

1. inspect the diff
2. compare the change with AGENTS.md
3. compare the change with CLAUDE.md
4. compare the change with FOUNDATION
5. compare the change with relevant docs
6. run formatting
7. run analysis
8. run tests
9. identify concrete problems
10. avoid unnecessary rewrites

A different coding style alone is not sufficient reason to rewrite working code.

---

# 31. Current Development Status

The current implementation includes:

- Flutter application initialization
- Welcome screen
- Onboarding
- Human display name
- Life Project area selection
- Goal definition
- AI support preference selection
- Onboarding completion
- Home screen
- Next Action planning flow
- Calendar domain
- Calendar repository abstraction
- In-memory calendar repository
- Calendar repository tests
- Initial calendar month view
- Date selection
- Selected-day event list

---

# 32. Current Development Focus

The current development sequence is:

```text
1. Calendar Event Editor
2. Calendar event creation
3. Calendar event editing
4. Calendar event deletion
5. Available-time calculation
6. Calendar → Next Action integration
7. Action → Calendar registration
8. Journey
9. Reflection
10. Persistent storage
11. AI integration
12. External calendar integration
```

Do not skip directly to advanced integrations unless explicitly requested.

---

# 33. Calendar MVP Scope

Current Calendar MVP should support:

- monthly calendar
- date selection
- event list
- event creation
- event editing
- event deletion
- all-day events
- timed events
- event category
- Life Project relation
- AI visibility
- simple available-time calculation
- Next Action integration

Not currently required:

- Apple Calendar synchronization
- Google Calendar synchronization
- complex recurrence rules
- collaborative scheduling
- automatic AI rescheduling

---

# 34. Future Persistence

The current repository is intentionally in-memory.

Future storage will likely use Supabase.

Expected future structure:

```text
CalendarRepository
        ↑
        ├── InMemoryCalendarRepository
        └── SupabaseCalendarRepository
```

Do not make presentation code dependent on Supabase.

Persistence must remain behind repository abstractions.

---

# 35. Future External Calendar Integration

External calendar integration may eventually include:

```text
Apple Calendar
Google Calendar
```

Possible user-controlled modes:

```text
Read only
Write only
Bidirectional sync
Busy-time only
No connection
```

Never assume external calendar access is granted.

Permissions must be explicit.

---

# 36. Privacy by Design

Privacy must be part of the architecture, not added later.

Calendar AI visibility:

```text
full
busyOnly
hidden
```

Meaning:

```text
full
AI may understand event details.

busyOnly
AI may only understand that the time is occupied.

hidden
AI must not use the event.
```

Future AI integration must respect these values.

---

# 37. Human Confirmation Before External Effects

Any action that changes external state should require clear user confirmation.

Examples:

- create calendar event
- modify calendar event
- delete calendar event
- send shared information
- synchronize external calendars
- change family-sharing settings

AI suggestion alone is never sufficient authorization.

---

# 38. Avoid Premature Automation

Do not turn AI Life Partner into an automatic scheduler.

The intended model is:

```text
Understand
    ↓
Think together
    ↓
Suggest
    ↓
Human decides
    ↓
Act
    ↓
Journey
    ↓
Reflect
```

Not:

```text
AI decides
    ↓
AI schedules
    ↓
Human follows
```

---

# 39. Completion Report

After completing an implementation task, provide a short report containing:

## Files changed

List files that were created or modified.

## Behavior

Explain what was added or changed.

## Verification

Report commands executed.

Example:

```text
dart format lib test
flutter analyze
flutter test
```

## Results

Example:

```text
No issues found!
All tests passed!
```

## Manual verification

Describe what the user should test in the UI.

## Limitations

State what is intentionally not yet implemented.

## Suggested commit message

Provide one focused Git commit message.

---

# 40. Final Principle

AI Life Partner is not built to control a person's life.

It exists to accompany a person through life.

People may:

- move forward
- stop
- reconsider
- change direction
- rest
- fail
- try again

All of these experiences are part of their Journey.

AI should understand that Journey,

help the person reflect on it,

and support them in thinking about the next step.

> **Human is the center.**
>
> **AI is the partner.**
>
> **Growth is the purpose.**
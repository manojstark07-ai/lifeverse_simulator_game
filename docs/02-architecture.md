# Technical Architecture

## Stack (as built)

| Concern | Choice | Notes |
|---|---|---|
| UI | Flutter 3.44 / Dart 3.12, Material 3 | Responsive: NavigationBar on phones, NavigationRail ≥ 840 dp |
| State | `flutter_bloc` (Cubits) | `GameCubit` (session), `SettingsCubit`; screens keep local UI state |
| Navigation | `go_router` 18 | Guarded routes; `/hub?tab=` deep links |
| 2D world | `flame` 1.38 | Isometric city map, direct-control city mode and lightweight interiors |
| Charts | `fl_chart` | Cash and debt history |
| DI | `get_it` | `configureDependencies()` with test overrides |
| Persistence | Versioned JSON save files (`path_provider`) | See *Decisions* (no Isar) |
| Cloud / Firebase | Designed, not wired | Phase 8; see below |

## Layers

```
lib/
├── engine/          PURE DART — no Flutter imports; runs in tests and headless sims
│   ├── core/            Rng (mulberry32), GameCalendar, money formatting, JSON helpers
│   ├── content/         ContentBundle (merged JSON docs), ContentValidator (story-graph linter)
│   ├── conditions/      Condition — declarative predicates (39 kinds)
│   ├── effects/         Effect (28 kinds) + EffectResolver
│   ├── character/       content models, PlayerProfile, CharacterFactory, stat/skill keys
│   ├── time/            Routine, RoutineBudget, LifeSimulation (days, months, random events)
│   ├── story/           story models, StoryEngine (trigger → node → choice → route)
│   ├── puzzles/         Puzzle, PuzzleSelector (stratified + adaptive)
│   ├── exams/           ExamDefinition (versioned), ExamService (scoring)
│   ├── education/  career/  finance/  relationships/   per-module models + services
│   ├── achievements/  endings/  journal/  actions/
│   ├── game_state.dart  the single serialisable state aggregate
│   ├── engine_context.dart  draft state + shared services for one operation
│   ├── game_events.dart     domain events emitted to the UI
│   └── game_engine.dart     FAÇADE — the only API the app calls
├── data/            ContentRepository (assets), SaveRepository (+ migrations), SettingsRepository
├── app/             DI, router, theme, FeedbackHost, dev demo launcher
├── features/        one folder per screen/feature (cubits + widgets)
└── shared/          avatar painter, common widgets
assets/content/      index.json + 10 JSON documents (all game content)
test/                engine, data, widget tests + autoplayer support
tool/                balance_report.dart (headless 60-life balance sweep)
```

## Key mechanisms

**Transactional operations.** Every `GameEngine` command clones the state, applies all changes
to the clone through an `EngineContext`, then runs post-operation housekeeping: prune the
event queue, trigger due events and evaluate achievements. If any step throws, the clone is
discarded and a `RuleViolation` reaches the UI, so a decision touching finance, relationships
and education commits all of its changes or none of them. Inputs are never mutated (tested).

**Determinism.** All randomness comes from one `Rng` whose 32-bit state is saved with the
game. The same seed and decisions always replay byte-for-byte (tested). Practice and mock
papers use derived RNGs, so browsing practice never perturbs the main timeline.

**Orchestration, not mesh.** Modules never call each other ad hoc. `LifeSimulation.settleMonth`
is the orchestrator and runs a fixed order:

1. Income
2. Arrears
3. Living costs
4. Loans
5. Routine effects
6. Education
7. Relationships
8. Savings interest
9. Snapshot

Story consequences go through `EffectResolver`, which delegates to the module services. The
UI sees results through `GameEvent`s:

- `MonthSettled`
- `AchievementUnlocked`
- `StoryEventStarted`
- `ChapterConcluded`
- `DecisionOutcome`
- `Notice`

**Idempotence and invariants.** Month settlement is guarded by `lastSettledMonthKey`.
Achievements are a map keyed by id, so each can unlock once. Memories are unique per tag.
Cash never goes negative because shortfalls become arrears. Time only moves forward. The
autoplayer asserts these invariants after every step.

**Navigation ownership.** The hub opens story events (it is always the base of the in-game
stack). The story screen leaves them: it pops, or goes to the conclusion when the chapter
advanced. `FeedbackHost` only shows toasts and month summaries, which avoids racing
navigations.

## Persistence

- One file per slot (`autosave`, `slot1..3`) under `Documents/lifeverse/saves`, written
  atomically (temp file plus rename).
- Format: `{format, meta, state}`. The metadata drives the slot list without decoding the
  state.
- `GameState.schemaVersion` with a `SaveMigrator` chain (vN → vN+1 on raw JSON). Saves from a
  newer game version are refused clearly.
- Saving mid-event is supported. A pending challenge stores its generated puzzle ids, so
  resuming shows the same paper. Re-choosing to re-roll the paper is rejected.

## Content pipeline

`assets/content/index.json` lists documents. Top-level keys (`events`, `puzzles`, `careers`,
…) merge across documents, so packs add files without engine changes. In debug builds and in
CI, `ContentValidator` runs on startup and fails on:

- unknown references
- broken or unreachable nodes
- nodes without a free fallback choice (soft-lock guard)
- flags read but never set
- scheduled events nothing schedules
- under-sized puzzle pools
- exams where performance weighs less than 50%
- non-fictional exams without a source or verification date
- MCQ answers out of range
- missing fallback conclusions

## Environment integration: cloud & server

The repository includes the offline-first provider contract and deterministic
conflict resolver. A product environment still needs to supply Firebase Auth,
Firestore configuration and receipt-verification functions before this can be
connected to a real account.

- **Firebase Auth** (anonymous, upgradable) and a Firestore document per cloud save at
  `users/{uid}/saves/{slot}` holding `{meta, stateGzipB64, schemaVersion, deviceId, updatedAt,
  playthroughId, day}`.
- **Conflict rule:**
  1. Same `playthroughId`: keep the larger `day`. On a tie, keep the newest `updatedAt`.
  2. Different playthroughs: never overwrite; surface both and let the player choose.
  3. The local autosave is never deleted by sync.
- **Server authority:** purchases are verified by Cloud Functions with store receipts, and
  entitlements live in `users/{uid}/entitlements`, which clients can read but not write.
  Clients never decide their own purchases.
- **AI extensions** (optional, off by default) may only produce *presentation* text: dialogue
  flavour, interview question phrasing and summaries. They run behind a function with
  validation, caching and spend caps. They cannot emit effects. Consequences stay authored.

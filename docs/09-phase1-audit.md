# Phase 1 Audit: Playable Foundation

Audit date: 3 October 2026

## Existing foundation

The project already has a working Phase 1 slice:

- Character creation starts a life at age 18 with background, city, traits, interests and ambition.
- `GameEngine` is the transactional facade over a serialisable `GameState`.
- `GameCalendar` and `LifeSimulation` advance deterministic days and idempotent months.
- Story events are data-driven, conditional, branching and challenge-aware.
- Delayed effects are scheduled as raw, save-compatible effects and applied when due.
- `DecisionRecord` and `JournalEntry` provide a persistent decision history.
- Local saves are atomic, slot-based and migrated by schema version, including mid-event saves.
- The content validator checks references, story graphs, conditions, effects, puzzle pools and fallback conclusions.

## Gaps found and addressed in this pass

1. The roadmap and data-model documents were stale after the market expansion. This audit records the current boundary and keeps Phase 1 separate from the next gameplay phase.
2. The Journey screen exposed raw history but did not explain the current state that history produced. It now shows age/date/location, current objective, queued delayed consequences, recent decision count and the current life chapter before the detailed tabs.
3. Foundation invariants existed across several tests but had no single Phase 1 regression file. `phase1_foundation_test.dart` now covers deterministic opening branches, delayed consequences, monotonic time, monthly idempotence and save round-tripping.

## Current boundary

- Flame movement, collisions, joystick controls, NPC interaction and indoor scenes are implemented in the world feature.
- Boxing combat remains a non-graphic timing/control mini-game; the sports timing and conflict screens are intentionally separate activities.
- Business finances, taxes, insurance and retirement live in the long-term life systems layer.
- Death, retirement, legacy mode and New Life+ have persistent local state and engine commands.
- A real Firebase/Firestore provider remains an environment integration; the repository ships the offline-first contract and conflict resolver without inventing credentials.

## Exit criteria

Phase 1 is considered stable when character creation, event choices, delayed consequences, calendar settlement, timeline history and save/load remain deterministic and transactional. Future phases must call the existing engine facade and preserve these contracts.

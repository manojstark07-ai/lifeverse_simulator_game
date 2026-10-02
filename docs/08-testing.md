# Test Requirements & Coverage

Run everything with `flutter test` (55 tests). Run the balance sweep with
`flutter test tool/balance_report.dart`.

| Area | File | What is verified |
|---|---|---|
| Content & story graph | `test/engine/content_validation_test.dart` | Validator passes; slice content volume; every puzzle's answer checks; exam labelled fictional; validator catches missing nodes, unreachable nodes, soft-locks, unset flags |
| Long-running playthroughs | `test/engine/playthrough_test.dart` | Engineering → government seat → software developer; commerce → accountant; trade → electrician (< ~3 years); double exam failure → drop year → complete chapter; **24 randomised seeds × 3 backgrounds × varied accuracy** never violate invariants or soft-lock; determinism; post-chapter sandbox earns and promotes |
| Finance | `test/engine/finance_test.dart` | EMI formula; amortisation sums; Indian number format; moratorium accrual → capitalisation → EMI; missed EMI penalty and credit; default; prepay closes and sets debt-free; loans need a bank account; month settlement idempotent |
| Exams | `test/engine/exam_test.dart` | Stratified, reproducible papers; +4/−1/0 marking; blank paper + max prep fails; perfect paper wins; prep shifts borderline; adaptive difficulty; numeric tolerance |
| Engine rules | `test/engine/engine_rules_test.dart` | Start state; creation validation; background ≠ ability; transactional rejection; inputs never mutated; 2 activities/day; exhaustion; no duplicate practice rewards; routine normalisation; overwork vs energy; advance stops at events; running out of money → recovery event; **saving mid-challenge** resumes the same paper and blocks re-rolls; delayed consequences; memories and variants; living-cost rules |
| Saves | `test/data/save_repository_test.dart` | Round-trip incl. mid-event; branch replay identical; delete; path validation; corrupt slot reported; atomic write; v0 → v1 migration; newer-version refusal |
| UI flows | `test/widget/app_flow_test.dart` | Title → creation → story → hub → activity; story puzzle → review → result node; Exam Centre practice → manual save with label |

**Invariants checked after every autoplayer step:**

- time is monotonic; cash and arrears are never negative
- stats, skills and relationship values stay in range
- loans are never negative; credit score stays in 300–900
- an active event always has a node
- at most 2 actions per day
- settlement never runs backwards
- no duplicate achievement unlocks

**Gaps to close next:**

- golden tests per screen (light and dark)
- Flame map tap test
- integration tests on device (`integration_test`)
- a property-based fuzzer over random content packs
- performance budget for 10-year sandbox runs

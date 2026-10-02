# Staged Implementation Plan

| Phase | Scope | Status |
|---|---|---|
| **1. Playable foundation** | Flutter project, clean layering, theme, character creation, 5 attributes, day/month clock, local saves, opening story | **Done** |
| **2. Education & puzzles** | 3 pathways, fictional UTAT, puzzle engine (MCQ/numeric, timer, review), adaptive practice, mocks, semesters, scholarship | **Done (slice)** |
| **3. Jobs & careers** | Part-time job, 3 careers + founder path, interviews, negotiation, salary, promotions | **Done (slice)** |
| **4. Money & personal life** | Banking, education/personal/consumer loans, EMIs, arrears, credit score, 3 NPCs with memories, delayed consequences | **Done (slice)** |
| 5. Entrepreneurship & investing | Fictional exchange, portfolios, monthly market turns, business P&L, projects, hiring, funding, taxes, property, insurance and retirement | Done |
| 6. Expanded world | Additional cities, travel, 50+ authored career entries, direct Flame action mode and location interactions | Done (slice) |
| 7. Long-term life | Chapters 2–6, ageing, retirement, end-of-life, legacy archive and New Life+ comparison | Done (slice) |
| 8. Production | Offline-first cloud sync contract, conflict reconciliation, ARB locale packs, language setting, reduced motion, text scaling and analytics opt-in | Done (local foundation) |

## Next three milestones (recommended order)

1. **Content tooling.** Move story authoring to a typed source format with a CLI exporter (the
   current JSON was produced with an authoring script), and add a graph-visualiser debug
   screen.
2. **Cloud provider hookup.** Implement the `CloudSyncProvider` contract with Firebase Auth and
   Firestore credentials supplied by the product environment.
3. **Production art pass.** Replace procedural placeholders with original sprite sheets, add
   audio, and profile Flame scenes on target phones.

## Rules for adding real exams

Real exam configurations (JEE, NEET, CAT, UPSC, …) must set `fictional: false` with
`source` (an official notice URL) and `verifiedOn`. The validator rejects them otherwise.
Questions stay original and are labelled as practice.

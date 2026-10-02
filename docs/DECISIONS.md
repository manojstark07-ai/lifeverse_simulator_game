# Decision Log

Where the brief left room, these are the calls made and why.

1. **JSON save files instead of Isar.** The original Isar project is no longer actively
   maintained, and the save access pattern is "read or write one whole document per slot".
   Versioned JSON with atomic writes and a migration chain is simpler, inspectable and fully
   testable without native binaries. If queryable history is needed later (analytics,
   cross-life comparisons), `drift` (SQLite) is the recommended replacement behind the same
   `SaveRepository` interface.
2. **No Firebase in the slice.** The game is offline-first, and wiring Firebase requires
   project credentials. The cloud schema, conflict rules and server-authority rules are
   designed (`02-architecture.md`) for Phase 8.
3. **Flame only for the city map.** Narrative, finance and management screens are standard
   Flutter, per the brief. Rive and Lottie are deferred until real art assets exist; the
   avatar is a procedural `CustomPainter`, so it costs no assets and supports any combination.
4. **A fictional exam (UTAT) instead of JEE.** Real eligibility rules and formats must come
   from verified sources. The schema supports real exams but the validator requires `source`
   and `verifiedOn`. All puzzles are original.
5. **Performance outweighs preparation (70/30), enforced by the validator.** This guarantees
   exams can never be won by stats or luck alone.
6. **Whole rupees, not paise.** Interest is rounded per month. The drift is negligible at game
   scale, and integer money removes floating-point errors in balances.
7. **A day counter for the clock, starting 1 June 2026, aged 18.** Simple, monotonic and
   serialisable. Calendar dates are derived values.
8. **Hybrid time:** 2 focused activities per day plus a weekly routine for skipped days, with
   monthly settlement. This keeps opportunity costs real without forcing 1,400 daily turns
   per degree.
9. **Arrears instead of negative cash.** Impossible financial states can't be represented, and
   overdue bills become a story (the money-crisis event) rather than a crash or a game over.
10. **Seeded randomness everywhere, including "luck" in story (`roll` effect).** Outcomes are
    uncertain for players but reproducible for tests, bug reports and replays.
11. **Lifestyle multiplier on backgrounds.** Without it, affluent players banked ₹4–10 lakh by
    21. Habits, not ability, differentiate backgrounds.
12. **Background doesn't touch Knowledge.** It changes cash, support, obligations and
    narrative variants only, so background never predetermines ability.
13. **The "Long Way Round" is a real ending.** Dropping out or stepping away from job hunting
    concludes the chapter with dignity rather than failing the player.
15. **Visual identity.** Plus Jakarta Sans for the interface and Fraunces for display and
    narrative text, both under the OFL licence and bundled as static weights so the game works
    offline. Dusk palette: violet → coral gradients on warm cream or deep night. Branded
    dialogs, gradient call-to-action buttons and animated selection cards live in
    `lib/shared/design.dart`.
16. **Mature themes as a content pack plus a toggle.** Engine features stay generic (monthly
    rules, interview modifiers, conditional locations) and the content gates on `mature_on`.
    Romance is adult, mutual and non-explicit by construction: "yes" requires the other
    character's closeness and trust.
14. **Debug demo launcher (`--dart-define=LV_DEMO=/route`).** Seeds a life and opens any
    screen, for design review and screenshots. It is compiled out of release behaviour via
    `kDebugMode`.
17. **Fictional brands for real-world goods.** Phones, cars and platforms are parodies ("PearPhone",
    "Bavaria", "ViewTube") so the game never implies endorsement and never goes stale when real
    models change. Prices are pegged to 2026 Indian market levels.
18. **Possessions are content, not code.** A shop item declares its price, upkeep, depreciation
    (negative means it appreciates), slot (a new phone trades in the old one), financing and effects.
    Lenders cap EMIs at half of monthly income, so a student can't buy a Bavaria on credit.
19. **Events with `chapter: 0` can fire in any chapter.** Everyday life (a stolen phone, a viral
    video, a health scare) shouldn't depend on the plot's chapter. Adult-life arcs (proposals, the
    wedding, children, divorce) are Chapter 2, so Chapter 1 balance is unchanged.
20. **The partner is engine state, not just flags.** `household` tracks one partner, their status,
    marriage and children. Content addresses them with `"npc": "partner"`, so one date-night action
    works for every possible partner. Old dating flags remain for compatibility.
21. **Marriage and family aren't behind the mature toggle; dating apps, drinking and smoking are.**
    Arranged matches, weddings and children are family life. The toggle keeps its promise of
    "alcohol, smoking, crime and dating".
22. **Creators earn on a delay and decay without effort.** Ad revenue needs 1,000 subscribers and
    40,000 views; channels idle for 45 days lose subscribers. Fame follows subscribers on a log
    scale, so the first 10,000 matter as much as the next 90,000.
23. **Look-alike exams, not real ones.** NEXT-Med, CLAE, GMET, USE, SSE, SST-GL, NBPE, RRT, SPCT, NDE, CDE
    and TET stand in for NEET, CLAT, CAT, UPSC, state PSCs, SSC, IBPS, RRB, police, NDA, CDS and TET.
    This extends decision 4: players recognise the ladder, but no real rule or cut-off is claimed.
24. **Real employer names (reverses part of 17).** Job portal employers are real companies (TCS, Apollo
    Hospitals, McKinsey, IndiGo…) because players asked for them. They are only names on an offer
    letter; brands of goods, banks and platforms stay fictional.
25. **Crime and gambling are content, gated by the mature toggle.** A `heat` counter raises the odds of
    arrest; arrests offer fines, bribes, lawyers or jail (`cost.days`), and the engine's `loseJob` effect
    ends employment. They reuse the existing `police_record` flag, which blocks government exams until
    rehabilitation seals it. Gambling is seeded `roll`s with a negative expected value.
26. **Life problems teach coping, not just consequences.** Each problem offers healthy and unhealthy
    responses, and each ends with a short reflection. Healthy choices build `coped_well`, which unlocks a
    monthly resilience bonus.

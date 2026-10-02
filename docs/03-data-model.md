# Domain Models & Storage Schema

All engine models live in `lib/engine/**` and serialise to plain JSON. Money is **whole
rupees (int)**. Attributes and skills are 0–100 doubles. Time is an int `day` (0 = 1 Jun
2026).

## Runtime state (saved)

```
GameState                         (game_state.dart, schemaVersion = 3)
├─ playthroughId, seed, rngState, day, actionsToday, chapter, conclusionId/Day
├─ lastSettledMonthKey            idempotence guard for monthly settlement
├─ profile: PlayerProfile         name, pronouns, Appearance, birthDate, hometownId,
│                                 currentCityId, backgroundId, traitIds, interestIds, ambitionId
├─ stats {key→double}             knowledge · discipline · communication · wellbeing · energy ·
│                                 health · looks · fame
├─ skills {key→double}            programming · mathematics · accounting · electrical · business ·
│                                 content · styling · cooking
├─ finance: FinanceState          cash, hasBankAccount, bankName, creditScore (300–900),
│   ├─ transactions [Txn]         day, amount(±), category, label, balanceAfter (last 400)
│   ├─ loans [Loan]               product, rate, term, principalDisbursed, outstanding,
│   │                             accruedInterest, repaymentStartMonthKey, emi, paid/missed…
│   ├─ arrears, monthsInArrears, familySupportMonthly
│   ├─ history [MonthlySnapshot]  monthKey, cash, debt, income, expenses
│   ├─ quotes {stockId→StockQuote} fictional market price/history
│   └─ holdings [StockHolding]    stockId, shares, averageCost
├─ education: EducationState      programId, tierId, status, monthsCompleted, semesterGpas,
│                                 backlogs, scholarshipShare/Name, completedPrograms, feesPaidSemesters
├─ career: CareerState            partTimeJobId, careerId, level, monthsInRole/Career,
│                                 performance, monthlySalary, employer, history
├─ relationships {npc→RelationshipState}  affinity, trust, conflict, met, lastInteractionDay,
│                                         memories [Memory(day, tag, text, weight)]
├─ routine: Routine               weekly hours: study, exercise, social, family
├─ story: StoryProgress           activeEventId/NodeId, pendingChallengeChoiceId,
│                                 pendingPuzzleIds, lastOutcomes, completed, lastFiredDay, queue
├─ flags {string}, counters {string→int}
├─ scheduled [ScheduledEffects]   delayed consequences (dueDay, note, raw effects)
├─ journal [JournalEntry], decisions [DecisionRecord]
├─ achievements {id→day}, exams {id→ExamRecord(attempts, mockCount, bestMockPct)}
├─ solvedPuzzles {id}
├─ possessions [OwnedItem]        uid, itemId, boughtDay, pricePaid, loanId?
├─ household: HouseholdState      partnerId, status (single/dating/engaged/married), sinceDay,
│                                 marriedDay, divorces, exes, children [Child(name, birthDay)]
├─ creator: CreatorState?         channelName, nicheId, subscribers, totalViews, monthViews, videos,
│                                 monetized, fullTime, lifetimeEarnings, sponsorships, recent [VideoRecord]
└─ life: LifeSystemsState         businesses, projects, properties, insurance, retirement, taxes,
                                  ageing, retirement/death state, visited cities and legacy records
```

**Prompt → slice mapping:**

| Prompt entity | Slice model |
|---|---|
| Player | `PlayerProfile` |
| GameSession | `GameState` + `GameSession` (UI) |
| CharacterStats | `stats` / `skills` |
| GameClock | `day` + `GameCalendar` |
| WorldState | `flags`, `counters`, `story.queue` |
| StoryFlag | `flags` |
| DecisionHistory | `decisions` |
| Relationship | `RelationshipState` |
| EmploymentContract | `CareerState` |
| FinancialAccount | `FinanceState` |
| Transaction | `Txn` |
| SaveSlot | `SaveSlotMeta` |

Shop possessions remain in `possessions`; long-term property, business and legacy records live in `LifeSystemsState`. The fictional investment exchange remains inside `FinanceState` so quotes and holdings survive saves.

## Authored content (read-only, `assets/content/*.json`)

| Key | Model | Highlights |
|---|---|---|
| `backgrounds` | `Background` | startingCash, familySupportMonthly, lifestyleCostMultiplier, flags, obligations |
| `hometowns` | `Hometown` | livingCostMonthly, rentMonthly, wageMultiplier, commuteHoursWeekly |
| `traits` / `interests` / `ambitions` | | trait `modifiers` (knowledgeGain, skillGain, …) |
| `programs` | `EducationProgram` | durationMonths (whole semesters), admission (`exam`/`open`), tiers, skill gains, gradeSkill, practicePool |
| `exams` | `ExamDefinition` | version, fictional, disclaimer, pool, questionCount, marking, weights, preparation formula, tiers, maxAttempts, source?, verifiedOn? |
| `puzzles` | `Puzzle` | category, difficulty 1–3, pools, `mcq`/`numeric`, answer, tolerance, explanation, timeLimitSec, passage? |
| `careers` | `Career` | requiredPrograms (empty = open to all), requires + requirementNote, employers, primarySkill, interviewPool, demand, ladder [title, salary, minMonths, skillRequired], listed |
| `partTimeJobs` | `PartTimeJob` | weeklyHours, monthlyPay, gains |
| `loanProducts` | `LoanProduct` | kind (`education`/`personal`/`consumer`/`vehicle`/`home`), rate, max, term, grace |
| `shopItems` | `ShopItem` | category, price, monthlyUpkeep, annualDepreciationPct (negative appreciates), slot, loanProduct + downPaymentPct, commuteHoursSaved, creatorQuality, requires, onBuy/onSell/monthlyEffects, perks |
| `creatorNiches` | `CreatorNiche` | rpm, reach, sponsorRate, skillWeights (stats or skills), titles |
| `childNames` | list | names offered by `haveChild: auto` |
| `npcs` | `Npc` | personality, interests, isFamily, routineBond (`family`/`social`/`none`) |
| `locations` / `actions` | `MapLocation` / `DailyAction` | grid position, mapLabel; action costs, requirements, effects |
| `events` | `StoryEvent` | see `04-narrative-schema.md` |
| `achievements` / `conclusions` / `epilogueLines` | | condition-driven |

## Repositories

```dart
abstract class SaveRepository {      // FileSaveRepository, InMemorySaveRepository
  Future<List<SaveSlotMeta?>> listSlots();
  Future<GameState?> load(String slotId);           // migrates old schema versions
  Future<SaveSlotMeta> save(String slotId, GameState s, {String? label});  // atomic
  Future<void> delete(String slotId);
}
abstract class SettingsRepository { Future<AppSettings> load(); Future<void> save(AppSettings s); }
class ContentRepository { Future<ContentBundle> load(); }   // validates in debug
```

**Indexing:** saves are small (tens of KB), so whole-document JSON is simpler and faster than
a database for this access pattern (load one slot, save one slot). In-memory maps index
content by id.

## Cloud schema when a provider is connected

```
users/{uid}
  profile: {createdAt, locale}
  entitlements/{sku}: {grantedAt, source: "play"|"appstore", receiptId}   ← server-written only
  saves/{slot}: {meta, schemaVersion, playthroughId, day, deviceId, updatedAt, stateGzipB64}
```

Security rules: users read and write only their own `saves`. `entitlements` are read-only to
clients and written by a Cloud Function after receipt verification.

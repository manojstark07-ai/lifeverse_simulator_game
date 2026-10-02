# Narrative Data Schema

Story content is JSON under `assets/content/`, so it can be written by narrative designers and
linted by `ContentValidator` (run in tests and on debug start-up).

## Event

```jsonc
{
  "id": "ev_amma_hospital",            // unique across all documents
  "chapter": 1,                     // 0 = can happen in any chapter
  "title": "A Call at 6 am",
  "location": "hospital",               // must be a map location id
  "summary": "A family emergency tests your savings and your priorities.",
  "trigger": {
    "kind": "auto",                     // auto | scheduled | random
    "when": { /* Condition */ },        // optional; defaults to always
    "priority": 75,                     // auto: highest wins when several are ready
    "chancePerMonth": 0.1               // random only, (0, 1]
  },
  "repeatable": false,                  // auto+repeatable: 90-day cooldown; random: 120-day cooldown
  "worldEvent": false,                  // recovery/random events (not counted as main story)
  "start": "start",
  "nodes": { "start": { /* Node */ }, "paid": { /* Node */ } }
}
```

- **Trigger kinds:**
  - `auto` events fire as soon as their condition holds while no other event is active.
  - `scheduled` events fire only via a `schedule` effect, and the validator requires that
    something schedules them.
  - `random` events are rolled monthly from the seeded RNG and queued for a random day in
    that month.

## Node

```jsonc
{
  "speaker": "amma",                    // npc id | "player" | "narrator"
  "text": "Base text. Supports {name} {hometown} {city} {program}.",
  "variants": [ { "when": {Condition}, "text": "Appended if this is the first match." } ],
  "onEnter": [ /* Effects applied when the node is entered */ ],
  "choices": [ /* Choice */ ]           // none ⇒ terminal node ("Continue" ends the event)
}
```

## Choice

```jsonc
{
  "id": "c_loan",                        // unique within the node
  "label": "Take a ₹30,000 personal loan (15% a year).",
  "hint": "Repayments start next month.",
  "requires": { /* Condition */ },       // locked choices show their requirement…
  "hideIfLocked": false,                 // …unless hidden
  "cost": { "money": 0, "energy": 6, "days": 0 },   // money blocks if unaffordable; days pass after resolution
  "effects": [ /* Effects */ ],          // immediate consequences
  "routes": [ { "when": {Condition}, "next": "nodeA" } ],  // evaluated after effects
  "next": "paid",                        // fallback destination; null ends the event
  "challenge": {                         // optional interactive challenge
    "kind": "puzzle",                    // puzzle | exam | interview
    "pool": "utat", "count": 1, "passFraction": 1.0,   // puzzle
    "examId": "utat",                    // exam: pass = any tier but the lowest
    "career": "accountant",              // interview: pool + weighted score vs threshold
    "onPass": { "effects": [], "next": "pass", "routes": [] },
    "onFail": { "effects": [], "next": "fail", "routes": [] }
  }
}
```

## Conditions (`{"type": …}`)

| Type | Fields | Meaning |
|---|---|---|
| `always` / `all` / `any` / `not` | `conditions` / `condition` | composition |
| `flag` | `key` | flag present |
| `stat` / `skill` | `key, op, value` | `op` ∈ `>= <= > < == !=` |
| `cash` / `debt` / `arrears` / `arrearsMonths` | `op, value` | finance |
| `age` / `day` / `month` / `chapter` | `op, value` | time |
| `background` / `hometown` / `city` / `ambition` / `trait` | `value` | identity |
| `educationStatus` / `program` / `graduated` | `value` | education |
| `monthsEnrolled` / `programProgress` / `cgpa` / `backlogs` | `op, value` | education progress |
| `relationship` | `npc, field (affinity/trust/conflict), op, value` | bonds |
| `memory` | `npc, tag` | NPC remembers a moment |
| `eventDone` / `daysSinceEvent` | `value` / `event, op, value` | story history |
| `examTier` | `exam, value, exact?, latest?` | result at least (or exactly) a tier |
| `examAttempts` | `exam, op, value` | |
| `partTime` / `career` | `value` (bool or id) | employment |
| `careerLevel` / `careerMonths` | `op, value` | |
| `owns` | `value` (item id) or `category` / `slot` | possessions |
| `relationshipStatus` | `value` (single/dating/engaged/married) | |
| `partner` | `npc?`, `field?` (affinity/trust/conflict), `op, value` | current partner |
| `children` / `yearsMarried` | `op, value` | |
| `creator` | no field = has a channel; `field` subscribers/videos/monetized/fullTime | |
| `counter` | `key, op, value` | e.g. `practiceSessions`, `interviews` |
| `hasLoan` | `value?` (kind or product) | |

## Effects (`{"type": …}`)

| Type | Fields |
|---|---|
| `stat` / `skill` | `key, delta` (positive deltas scale with trait modifiers) |
| `money` | `amount` (+credit / −mandatory: shortfall becomes arrears), `label`, `category` |
| `flag` / `clearFlag` / `counter` | `key` (+ `delta`) |
| `relationship` | `npc, affinity?, trust?, conflict?` |
| `memory` / `meet` | `npc, tag, text, weight` / `npc` |
| `journal` | `title, text, kind?, important?` |
| `openBankAccount` | `bank?` |
| `enroll` / `dropOut` | `program, tier` (`"fromExam"` uses the best exam tier) |
| `scholarship` | `share (0,1], name` (refunds the share of fees already paid) |
| `startPartTime` / `quitPartTime` | `job` |
| `hire` / `salary` | `career, employer?, salaryMultiplier?` / `percent` |
| `takeLoan` | `product, amount` (number or `"remainingFees"`) |
| `familySupport` | `delta` or `set` |
| `relocate` | `city, independent?` |
| `schedule` | `event, inDays` (target must be a `scheduled` event) |
| `delayed` | `inDays, note, effects[]` (delayed consequences, journaled on arrival) |
| `roll` | `key, chance` (seeded random flag, used with `routes`) |
| `if` | `when, then[], else[]` |
| `programSkill` | `delta` (the current or last course's grade skill) |
| `giveItem` / `loseItem` | `item` / `item` or `category` (a lost item's loan is still owed) |
| `partner` | `npc`, `status` (dating/engaged/married); a previous partner becomes an ex |
| `partnerStatus` | `status`; `single` ends the relationship (a divorce if married) |
| `haveChild` | `name`, or `auto` to pick from `childNames` |
| `creator` | `subsPercent` and/or `views` |

In `relationship`, `memory` and `meet`, `"npc": "partner"` targets the current partner, and the
effect is skipped when there is none.
| `achievement` / `endChapter` | `id` / — |

## Validation rules (all enforced)

1. Every id reference resolves (NPC, program, exam, tier, career, job, loan, event, location,
   achievement, stat, skill).
2. Every `next` or route target exists, and every node is reachable from `start`.
3. **Soft-lock guard:** every non-terminal node has at least one choice with no requirement
   and no money cost.
4. Flags that are read must be set somewhere: by content, an engine-owned prefix, or a
   background.
5. `scheduled` events must be scheduled by some effect. Random events need
   `chancePerMonth` ∈ (0, 1].
6. Challenge pools hold at least `count` puzzles. Exams weight performance ≥ 50%, with
   weights summing to 1 and the lowest tier starting at 0.
7. Every chapter that has conclusions has an `always` fallback.

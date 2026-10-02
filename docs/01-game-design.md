# LIFEVERSE — Game Design Document

> *Every choice creates a future, but no single choice should define an entire life.*

## 1. Pitch

LIFEVERSE is a story-driven life-simulation RPG for Android and iOS. You begin at 18 on the
day school results are published in modern India and live forward: education, exams, money,
work, family and friendship. The game is offline-first and single-player. It is also an
educational simulation: exams are puzzle-driven, and money behaves the way money really
behaves.

**Design pillars**

1. **Choices cost something.** Every action spends time, energy, money or an opportunity. You
   cannot do everything.
2. **Engagement, not grinding.** Exams and interviews are won by solving puzzles, with
   accumulated preparation as a supporting factor. Stats alone never pass an exam.
3. **No single path wins.** There are four careers, a business path and a "long way round"
   chapter ending. Background shapes resources, not ability.
4. **Setbacks are recoverable.** Failing an exam, running out of money or dropping out each
   lead to authored recovery stories, not game-over screens.
5. **People remember.** NPCs keep memories of meaningful moments, and those memories change
   later scenes.

## 2. Core loop

```
            ┌─────────── story event (node graph) ───────────┐
            │ text → choices (costs, requirements) →         │
            │ optional puzzle/exam/interview → consequences  │
            └──────────────────────┬──────────────────────────┘
                                   ▼
 Hub (today) ── daily activities (2/day) ── End day / Skip week / To next month
      ▲                                                   │
      │                 monthly settlement ◄──────────────┘
      │   income · bills · loans · learning · grades · career · bonds
      └──── journal & timeline record everything; autosave after every action
```

**Hybrid time.** The clock is a day counter (day 0 = 1 June 2026):

- **Day by day.** The player chooses up to two focused activities a day, each with an energy
  and sometimes a money cost.
- **Fast-forward.** *Skip a week* and *To next month* simulate the player's weekly routine.
  Time stops automatically when a story event fires.
- **Monthly settlement.** On the 1st of each month the previous month is settled: income,
  living costs, EMIs, the routine's effects on attributes, course progress and semester
  results, career performance, relationship drift and savings interest.

## 3. Character

**Character creation** has five steps: name, pronouns and a procedural avatar (skin tone, hair
style and colour, outfit, expression, accessory) → hometown and family background → 1–2
traits and up to 3 interests → life goal → review.

| Background | Savings | Monthly family support | Lifestyle cost | Notes |
|---|---|---|---|---|
| Farming family | ₹8,000 | ₹1,500 | ×1.0 | Need-based scholarship eligible; harvest obligations |
| City lower-middle-class | ₹25,000 | ₹4,000 | ×1.0 | Need-based scholarship eligible |
| Affluent family business | ₹1,50,000 | ₹12,000 | ×1.8 | Can afford private college; "take over the business" expectations |

Backgrounds never change Knowledge. They change cash, support, habits, flags and story
variants.

**Hometowns:** Chennai and Bengaluru (metro), and Vellanur in Tiruvannamalai district, a
fictional rural village. Each has its own living costs, rent, wage multiplier and commute
hours.

**Five core attributes (0–100):** Knowledge, Discipline, Communication, Well-being and Energy.
Knowledge is learned and decays without use; there is no innate IQ score.

**Five skills:** Programming, Mathematics, Accounting, Electrical work and Business sense.

**Traits** multiply growth, for example *Curious* gives Knowledge gain ×1.12 and *Empathetic*
gives bond gain ×1.2.

## 4. Education & exams (vertical slice)

| Pathway | Duration | Admission | Fees / year | Leads to |
|---|---|---|---|---|
| B.Tech CSE | 4 years | **UTAT** exam → government (₹55k) or private (₹1.6L) seat | indicative | Software developer |
| B.Com (Accounting & Finance) | 3 years | Open | ₹22k | Accountant |
| ITI Electrician | 2 years | Open | ₹6k | Electrician |

**UTAT** (Unified Technical Admission Test) is a *fictional* exam. It has 6 questions in 12
minutes, marked +4 for correct, −1 for wrong and 0 for a skip. The paper is generated from a
10-puzzle validated bank, stratified across categories (maths, logic, patterns, reading,
programming, science, time management). The final score is 70% paper performance and 30%
preparation, so a blank paper fails even with maximum preparation. Two attempts are allowed.
Failing leads to either a drop year (retake) or a switch to another pathway.

**Practice** (adaptive, 3 questions) and **mock tests** (full timed paper) cost a daily
activity. They give learning rewards only the first time each puzzle is solved, and every
answer is followed by an explanation.

**Semesters:** every 6 months a GPA is computed from Knowledge, the course skill, Discipline,
Energy, seeded noise and the result of any exam challenge. A GPA below 5 creates a backlog.
Backlogs must be cleared, or graduation is delayed and re-exam fees are charged.

## 5. Work

- **Part-time:** a counter job at Filter Kaapi Corner. It takes 16 hours a week, pays
  ₹7,000/month × the city wage multiplier, and builds Communication and Business. It can be
  taken or quit at the café.
- **Careers:** Software developer, Accountant, Electrician, plus the story-only *FixLab
  co-founder*. Each has a ladder of 3–6 levels, e.g. Trainee → Software Engineer → Senior →
  Tech Lead → Engineering Manager → CTO.
- **Interviews:** 2 career puzzles, scored together with skill, communication and institution
  reputation against a threshold that eases with market demand. Salary negotiation succeeds on
  merit (communication 50+ plus an internship or reference) or by a seeded roll.
- **Progression:** performance tracks skill, discipline, energy and well-being. The annual
  review gives a promotion if time, skill and performance (60+) allow, otherwise a 5% raise or
  nothing.

## 6. Money

- **Banking:** one savings account at 3% a year, credited monthly, with a full transaction
  history.
- **Loans** (all fictional products):
  - Education loan: 9.5%; moratorium until the course ends plus 6 months, with interest
    accruing and then capitalised.
  - Personal loan: 15%.
  - "No-cost" EMI: 0% plus a processing fee.
- **Repayments:** reducing-balance EMIs, amortisation schedules and prepayment. Missed EMIs
  add a penalty and lower the credit score; three in a row is a default.
- **Arrears:** cash never goes negative. Unpayable mandatory costs become arrears, and two
  months of arrears trigger the *Overdue* recovery event.

## 7. People

There are three persistent NPCs with personalities, interests and memories:

- **Amma (Lakshmi):** family.
- **Kavya Raman:** best friend, aspiring founder.
- **Mr. Joseph Fernandes:** retired maths teacher and mentor.

Bonds have closeness (−100..100), trust and tension. Routine hours keep bonds warm and
neglect cools them. Memories are tagged ("showed_up", "too_busy", "paid_hospital") and are
queried by later story variants, epilogue lines and achievements.

## 8. Story — Chapter 1 (age 18 → first job)

There are **24 story events** (including the drop-year retake pair and the interview retry),
**3 recovery events** (money crisis, burnout, dropping out) and **4 random world events**: 31
events and 105 nodes in total. See `05-chapter1-story-graph.md`.

**Conclusions** are chosen by priority: *Something of Our Own* (FixLab), *The First Commit*,
*Balanced Books*, *Live Wire* and the fallback *The Long Way Round*. Each is followed by
personalised epilogue lines (debt, scholarship, memories, drop year, frugality and others).
After the conclusion the life continues in a sandbox: salary, promotions and loans keep
running.

## 9. Mature life themes (optional, on by default)

A separate content pack (`story_mature.json`, 14 events) is gated on the `mature_on` flag.
Players switch it in Settings, and it applies to new lives and to the current one.

- **Dating:** two adult characters, Arjun and Nila (both 21). Asking someone out only succeeds
  if the feeling is mutual (closeness and trust ≥ 35); otherwise they say no, kindly. There is
  a birthday conflict, a commitment conversation and an amicable breakup option. "Not looking
  for romance" is always available. Nothing is explicit.
- **Smoking:** peer pressure at the tea stall, with a seeded chance of getting hooked. Being a
  smoker costs ₹1,500 a month and some well-being. Quitting can fail and be retried.
- **Alcohol:** a party where underage drinking risks a warden's notice and binge drinking risks
  trouble; a bar for players 21 and over; a drinking-pattern intervention; a drunk-driving ride
  dilemma.
- **Crime:** a leaked exam paper (malpractice), reselling stolen phones (a police case), a
  bribe at a traffic stop, betting apps, and a bar fight. A police record lowers interview
  scores through `interviewModifiers`.

These choices are never glamorised: every one has a monetary, health, legal or relationship
consequence, and there are always recovery paths.

## 10. Ethics & monetisation guardrails

- All currency is fictional and is never connected to real payments or brokerage.
- Exams are fictional and clearly labelled. Practice questions are original, and real exam
  configurations require `source` and `verifiedOn` (enforced by the validator).
- No purchase may ever buy exam success, money or story advantages. Future monetisation is
  limited to a premium edition, story or career packs and cosmetics.
- Health is abstracted (energy and well-being); nothing is medical advice.
- The romance arc (Chapter 2+) will involve adult characters, require consent, and always be
  optional.

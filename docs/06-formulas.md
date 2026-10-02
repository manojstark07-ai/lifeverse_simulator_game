# Economy & Progression Formulas

Everything here is implemented in `lib/engine/**` and covered by tests. All figures are
indicative and fictional. They are tuned for play, not as real-world advice.

## Time budget (per week)

```
free = 168 − 56 sleep − 21 essentials − commitments
commitments = course hours (B.Tech 32 · B.Com 24 · ITI 35) + part-time 16 + job 45–50 + commute (7–10)
planned = study + exercise + social + family     → scaled down proportionally if planned > free
leisure = free − planned
load = (commitments + study) / 91
```

## Daily energy

```
energyTarget = clamp(85 − max(0, load − 0.55)·90 + min(exercise, 6), 20, 95)
each day: energy += (energyTarget − energy) · 0.2
activities: energy −= cost   (2 activities per day; blocked if energy < cost)
```

## Monthly attribute drift

```
efficiency e = (0.55 + 0.45·energy/100) · (0.8 if wellbeing < 30)
Knowledge   += study·0.11·e·(1 − K/120)·traitMod
               + course 0.6–1.1·e·(1 − K/140)                 (−0.3 if idle & not enrolled)
Discipline  += (study ≥ 8 ? 0.6 : study < 3 ? −0.4 : 0.1) + 0.2 if exercise ≥ 3 + 0.3 if employed
Communication += social·0.06 + 0.3 if employed + part-time 0.5
Well-being  += (target − WB)·0.35, where
   target = clamp(50 + min(2·exercise,12) + min(social,10) + min(0.8·family,8)
                  + min(0.35·leisure,12) − max(0, load−0.75)·80 − moneyStress, 5, 95)
   moneyStress = 12 if arrears, 6 if cash < monthly living cost
Skills      += gain·e·(1 − skill/130)·traitMod   (course, part-time, career)
```

## Money

```
living = city.livingCost × background.lifestyleMultiplier × (1.6 if employed) (+ rent if independent) (×0.85 frugal)
semester fee = feesPerYear / 2 × (1 − scholarshipShare)
savings interest = floor(cash × 3% / 12)                       (with bank account)
EMI = P·r·(1+r)^n / ((1+r)^n − 1), r = APR/1200, rounded up
moratorium: accrued += round(outstanding·r) monthly, capitalised when repayment starts
missed EMI: outstanding += interest + ₹500, credit −35, 3 consecutive ⇒ default flag
on-time EMI: credit +4 (max 900); arrears month: credit −10
mandatory spend > cash ⇒ cash 0, remainder → arrears (paid first next month)
```

## Exams

```
performance% = clamp((4·correct − 1·wrong) / (4·questions), 0, 1) · 100
preparation  = clamp(0.6·Knowledge + 0.15·Discipline + 0.25·Mathematics
                     + min(12, 2·solvedPoolPuzzles), 0, 100)
composite    = 0.7·performance + 0.3·preparation
UTAT tiers: ≥ 62 government · ≥ 42 private · else no seat
```

Consequence: with no paper performance, even perfect preparation reaches only 30. A perfect
paper with modest preparation reaches about 78.

## Semester GPA (0–10)

```
GPA = 2.6 + 0.045·Knowledge + 0.03·courseSkill + 0.015·Discipline + 0.01·(Energy − 50)
      + noise(±0.4) + 0.6 (exam challenge passed) − 0.6 (failed / missed for a friend)
GPA < 5 ⇒ backlog; later GPA ≥ 6.5 clears one; graduation needs 0 backlogs
```

## Careers

```
interview = 0.5·puzzleFraction + 0.25·skill/100 + 0.15·communication/100 + 0.1·institutionReputation
pass if interview ≥ 0.55 − 0.1·demand
starting salary = level0 × (1 + (reputation − 0.5)·0.2) × negotiation × cityWage   (rounded to ₹100)
negotiation +8% if (communication ≥ 50 and (internship or reference)) or seeded roll (35%)
performance += (target − performance)·0.3,
  target = 25 + 0.4·primarySkill + 0.2·Discipline + 0.1·Energy + 0.1·Well-being + noise(±6)
every 12 months in role: promote if minMonths, skill and performance ≥ 60; else +5% if ≥ 50
```

## Relationships

```
positive affinity deltas × trait relationshipGain
routine bond ≥ 3 h/week: affinity += hours·(0.12 family | 0.08 friend)
neglect > 30 days: affinity −0.6 (family) / −1.5 (friend) per month
tension decays 2/month
```

## Balance check (tool/balance_report.dart, 60 randomised lives)

Ending spread from random play: Live Wire 24, Balanced Books 20, Long Way Round 10, FixLab 4,
First Commit 2. The software path requires deliberate exam play, which random agents rarely
manage. The *Long Way Round* comes mostly from random agents choosing to drop out during
money crises. Affluent lives no longer accumulate implausible savings since the lifestyle
multiplier was introduced.

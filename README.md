# LIFEVERSE

A story-driven life-simulation RPG for Android and iOS, built with Flutter. You start at 18 on
results day in modern India and live forward through exams, college, money, work, family and
friendship.

**This repository contains a complete, playable vertical slice of Chapter 1 (age 18 → first
job).** It includes:

- character creation with a procedural avatar
- 3 backgrounds and 3 hometowns
- 5 attributes and 5 skills
- day and month time
- 3 education pathways
- the fictional puzzle-based UTAT entrance exam (10 validated puzzles plus 18 more for
  courses, interviews and case studies)
- 14 entrance and recruitment exams (fictional look-alikes): UTAT and UTAT Advanced (engineering),
  NEXT-Med (medicine), CLAE (law), GMET (MBA), and government exams from the Union and State Services
  down to staff selection, banking, railways, police constable, defence and teaching. Register at the
  exam hall, prepare at the coaching centre, sit the paper, and take a seat or a government post
- 9 education pathways, including MBBS, nursing, pharmacy, law, an MBA and pilot training
- 44 careers plus a founder path and 10 part-time jobs, with a job portal (apply through an interview
  round, resign, switch fields). Employers are real Indian and global companies; many careers need no
  degree
- crime and gambling (mature toggle): street crime with rising police heat, arrests, bribes, lawyers and
  jail time, a gang career and a heist; a casino with lotteries, cricket betting, roulette and cards; loan
  sharks and gambling addiction, with rehabilitation, self-exclusion and counselling as ways out
- life problems and coping: anxiety, setbacks, grief, loneliness, money stress, family conflict and more,
  each with healthy and unhealthy ways to respond and a reflection on what helps. A wellbeing toolkit
  (journalling, meditation, therapy, reflection) and lasting resilience for coping well
- a creator career on ViewTube (fictional): 9 niches, uploads, viral hits, monetisation, sponsors,
  fame, going full-time
- banking, loans and credit, plus car, two-wheeler and home loans
- a shop: phones (including the "PearPhone"), laptops, gadgets, scooters, motorcycles and cars,
  fashion and gold, flats, and memberships, with EMIs, trade-ins, upkeep, depreciation and resale
- driving lessons and a licence; vehicles shorten your commute
- health, looks and fame stats; a gym, a salon (with an avatar makeover), a mall and a car showroom
- mature themes (toggleable): smoking and drinking with real health and money costs, plus help to
  quit; dating, including a dating app
- relationships through to marriage: arranged matches, proposals, a wedding at your budget, a
  honeymoon, children or adoption, marriage strain and divorce
- 7 persistent NPCs with memories (plus 4 potential partners)
- 60+ story and world events, including adult-life events in Chapter 2
- 5 chapter conclusions with personalised epilogues
- achievements, a life timeline, an isometric city map (Flame)
- autosave plus 3 save slots, and accessibility settings

## Run

```bash
flutter pub get
flutter run                                  # title screen
flutter run --dart-define=LV_DEMO=/story     # debug: jump into a seeded life
flutter run --dart-define="LV_DEMO=/hub?tab=1"   # …at the city map (also /finance, /exams, /conclusion)
```

## Test

```bash
flutter analyze
flutter test                                 # engine, content, saves, UI flows, long playthroughs
flutter test tool/balance_report.dart        # 60 randomised lives → outcome distribution
```

## Documentation

| Doc | Contents |
|---|---|
| [docs/01-game-design.md](docs/01-game-design.md) | Game design document |
| [docs/02-architecture.md](docs/02-architecture.md) | Architecture, folder structure, cloud and AI plans |
| [docs/03-data-model.md](docs/03-data-model.md) | Domain models, content schema, repositories, cloud schema |
| [docs/04-narrative-schema.md](docs/04-narrative-schema.md) | Story JSON schema: conditions, effects, validation |
| [docs/05-chapter1-story-graph.md](docs/05-chapter1-story-graph.md) | Chapter 1 event graph and persistent consequences |
| [docs/06-formulas.md](docs/06-formulas.md) | Economy and progression formulas |
| [docs/07-roadmap.md](docs/07-roadmap.md) | Staged implementation plan |
| [docs/08-testing.md](docs/08-testing.md) | Test requirements and coverage |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Decisions made where the brief was open |

## Adding content

Add a JSON document under `assets/content/` and list it in `assets/content/index.json`.
Content merges by key (`events`, `puzzles`, `careers`, …). Run `flutter test`: the content
validator lints references, the story graph (reachability, soft-locks), puzzles and exam
configurations.

*Banks, brands, products and exams in LIFEVERSE are fictional; exams are look-alikes with simplified rules.
Employers in the job portal are real companies, used only as names: nothing implies endorsement, and
salaries are indicative. Practice questions are original and are not official exam material.*

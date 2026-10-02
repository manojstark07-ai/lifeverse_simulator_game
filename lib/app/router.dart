import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/achievements/achievements_screen.dart';
import '../features/career/career_screen.dart';
import '../features/conclusion/conclusion_screen.dart';
import '../features/creation/character_creation_screen.dart';
import '../features/creator/creator_screen.dart';
import '../features/education/education_screen.dart';
import '../features/exams/exam_center_screen.dart';
import '../features/finance/finance_view.dart';
import '../features/finance/investments_screen.dart';
import '../features/hub/hub_screen.dart';
import '../features/lifestyle/makeover_screen.dart';
import '../features/lifestyle/shop_screen.dart';
import '../features/life/life_management_screen.dart';
import '../features/people/people_view.dart';
import '../features/profile/profile_view.dart';
import '../features/profile/desires_screen.dart';
import '../features/puzzles/puzzle_session_screen.dart';
import '../features/routine/routine_screen.dart';
import '../features/sports/fight_screen.dart';
import '../features/sports/sports_arena_screen.dart';
import '../features/saves/saves_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/splash/title_screen.dart';
import '../features/story/story_screen.dart';
import '../features/timeline/timeline_screen.dart';
import '../features/world/life_world_screen.dart';
import '../features/world/interior_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Routes that require an active game redirect to the title screen if none
/// is loaded (e.g. after a hot restart).
GoRouter buildRouter({
  required bool Function() hasGame,
  String initialLocation = '/',
}) => GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: initialLocation,
  redirect: (context, state) {
    const open = {'/', '/create', '/saves', '/settings'};
    if (!open.contains(state.matchedLocation) && !hasGame()) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, _) => const TitleScreen()),
    GoRoute(
      path: '/create',
      builder: (_, state) => CharacterCreationScreen(
        newLifePlus: state.uri.queryParameters['plus'] == '1',
      ),
    ),
    GoRoute(
      path: '/hub',
      builder: (_, state) => HubScreen(
        initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0,
      ),
    ),
    GoRoute(path: '/story', builder: (_, _) => const StoryScreen()),
    GoRoute(
      path: '/puzzle',
      builder: (_, state) =>
          PuzzleSessionScreen(args: state.extra! as PuzzleSessionArgs),
    ),
    GoRoute(path: '/education', builder: (_, _) => const EducationScreen()),
    GoRoute(path: '/exams', builder: (_, _) => const ExamCenterScreen()),
    GoRoute(path: '/career', builder: (_, _) => const CareerScreen()),
    GoRoute(path: '/routine', builder: (_, _) => const RoutineScreen()),
    GoRoute(path: '/timeline', builder: (_, _) => const TimelineScreen()),
    GoRoute(
      path: '/achievements',
      builder: (_, _) => const AchievementsScreen(),
    ),
    GoRoute(path: '/saves', builder: (_, _) => const SavesScreen()),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    GoRoute(
      path: '/finance',
      builder: (_, _) => const _Page(
        title: 'Accounts & loans',
        child: FinanceView(showHeading: false),
      ),
    ),
    GoRoute(path: '/investments', builder: (_, _) => const InvestmentsScreen()),
    GoRoute(path: '/sports', builder: (_, _) => const SportsArenaScreen()),
    GoRoute(path: '/fight', builder: (_, _) => const FightScreen()),
    GoRoute(
      path: '/people',
      builder: (_, _) =>
          const _Page(title: 'People', child: PeopleView(showHeading: false)),
    ),
    GoRoute(
      path: '/profile',
      builder: (_, _) => const _Page(title: 'Profile', child: ProfileView()),
    ),
    GoRoute(path: '/desires', builder: (_, _) => const DesiresScreen()),
    GoRoute(
      path: '/life-management',
      builder: (_, _) => const LifeManagementScreen(),
    ),
    GoRoute(path: '/world', builder: (_, _) => const LifeWorldScreen()),
    GoRoute(
      path: '/interior/:locationId',
      builder: (_, state) => InteriorScreen(
        locationId: Uri.decodeComponent(state.pathParameters['locationId']!),
      ),
    ),
    GoRoute(path: '/conclusion', builder: (_, _) => const ConclusionScreen()),
    GoRoute(
      path: '/shop',
      builder: (_, state) =>
          ShopScreen(initialCategory: state.uri.queryParameters['tab']),
    ),
    GoRoute(path: '/creator', builder: (_, _) => const CreatorScreen()),
    GoRoute(path: '/makeover', builder: (_, _) => const MakeoverScreen()),
  ],
);

/// Wraps a hub tab view so it can also be opened as a standalone page.
class _Page extends StatelessWidget {
  const _Page({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SafeArea(child: child),
  );
}

import '../core/json_utils.dart';

/// A kind of channel the player can run on ViewTube (a fictional video
/// platform). Niches trade audience size against ad rates and sponsorships.
class CreatorNiche {
  CreatorNiche({
    required this.id,
    required this.name,
    required this.description,
    required this.rpm,
    required this.reach,
    required this.sponsorRate,
    required this.skillWeights,
    required this.titles,
  });

  factory CreatorNiche.fromJson(Json j) => CreatorNiche(
        id: req<String>(j, 'id'),
        name: req<String>(j, 'name'),
        description: req<String>(j, 'description'),
        rpm: reqNum(j, 'rpm'),
        reach: reqNum(j, 'reach'),
        sponsorRate: reqNum(j, 'sponsorRate'),
        skillWeights: numMap(j['skillWeights']),
        titles: stringList(j['titles']),
      );

  final String id;
  final String name;
  final String description;

  /// Rupees earned per 1,000 monetised views.
  final double rpm;

  /// Audience-size multiplier (comedy reaches more people than finance).
  final double reach;

  /// Rupees per subscriber for one sponsored video.
  final double sponsorRate;

  /// Stat or skill key → weight in video quality. Weights sum to ~1.
  final Map<String, double> skillWeights;

  /// Flavour video titles; `{n}` is replaced with a number.
  final List<String> titles;
}

class VideoRecord {
  VideoRecord({required this.day, required this.title, required this.views, this.viral = false});

  factory VideoRecord.fromJson(Json j) => VideoRecord(
        day: j['day'] as int,
        title: j['title'] as String,
        views: j['views'] as int,
        viral: j['viral'] as bool? ?? false,
      );

  final int day;
  final String title;
  final int views;
  final bool viral;

  Json toJson() => {'day': day, 'title': title, 'views': views, 'viral': viral};
}

class CreatorState {
  CreatorState({
    required this.channelName,
    required this.nicheId,
    required this.startedDay,
    this.subscribers = 0,
    this.totalViews = 0,
    this.monthViews = 0,
    this.videos = 0,
    this.lastUploadDay,
    this.monetized = false,
    this.fullTime = false,
    this.lifetimeEarnings = 0,
    this.sponsorships = 0,
    List<VideoRecord>? recent,
  }) : recent = recent ?? [];

  factory CreatorState.fromJson(Json j) => CreatorState(
        channelName: j['channelName'] as String,
        nicheId: j['nicheId'] as String,
        startedDay: j['startedDay'] as int,
        subscribers: optInt(j, 'subscribers', 0),
        totalViews: optInt(j, 'totalViews', 0),
        monthViews: optInt(j, 'monthViews', 0),
        videos: optInt(j, 'videos', 0),
        lastUploadDay: j['lastUploadDay'] as int?,
        monetized: j['monetized'] as bool? ?? false,
        fullTime: j['fullTime'] as bool? ?? false,
        lifetimeEarnings: optInt(j, 'lifetimeEarnings', 0),
        sponsorships: optInt(j, 'sponsorships', 0),
        recent: jsonList(j['recent']).map(VideoRecord.fromJson).toList(),
      );

  static const maxRecent = 12;

  final String channelName;
  final String nicheId;
  final int startedDay;
  int subscribers;
  int totalViews;

  /// Views earned since the last monthly settlement (for ad revenue).
  int monthViews;
  int videos;
  int? lastUploadDay;
  bool monetized;

  /// Full-time creators upload on a schedule as part of their working week.
  bool fullTime;
  int lifetimeEarnings;
  int sponsorships;
  List<VideoRecord> recent;

  Json toJson() => {
        'channelName': channelName,
        'nicheId': nicheId,
        'startedDay': startedDay,
        'subscribers': subscribers,
        'totalViews': totalViews,
        'monthViews': monthViews,
        'videos': videos,
        'lastUploadDay': lastUploadDay,
        'monetized': monetized,
        'fullTime': fullTime,
        'lifetimeEarnings': lifetimeEarnings,
        'sponsorships': sponsorships,
        'recent': recent.map((v) => v.toJson()).toList(),
      };
}

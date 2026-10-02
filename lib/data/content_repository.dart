import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../engine/content/content_bundle.dart';
import '../engine/content/content_validator.dart';

/// Loads authored content from bundled assets.
///
/// `assets/content/index.json` lists the documents to merge, so new content
/// packs (careers, regions, chapters) ship as extra JSON files.
class ContentRepository {
  ContentRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  static const _root = 'assets/content';

  Future<ContentBundle> load() async {
    final index = jsonDecode(await _bundle.loadString('$_root/index.json')) as Map<String, dynamic>;
    final docs = <Map<String, dynamic>>[];
    for (final file in (index['documents'] as List).cast<String>()) {
      docs.add((jsonDecode(await _bundle.loadString('$_root/$file')) as Map).cast<String, dynamic>());
    }
    final bundle = ContentBundle.fromDocuments(docs);
    if (kDebugMode) {
      final report = ContentValidator.validate(bundle);
      if (!report.isValid) throw StateError('Content failed validation:\n$report');
    }
    return bundle;
  }
}

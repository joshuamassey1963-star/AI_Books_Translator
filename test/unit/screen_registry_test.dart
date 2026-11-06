import 'package:ai_book_translator/app/screen_registry.dart';
import 'package:ai_book_translator/core/feature_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('screen registry', () {
    test('has 4-5 bottom tabs (roadmap section 2)', () {
      expect(bottomTabs.length, inInclusiveRange(4, 5));
    });

    test('screen ids are unique', () {
      final ids = allScreens.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('sub-screen paths are unique and relative', () {
      final paths = moreScreens.map((s) => s.path).toList();
      expect(paths.toSet().length, paths.length);
      for (final p in [...paths, bookDetailsScreen.path]) {
        expect(p.startsWith('/'), isFalse, reason: p);
      }
    });

    test('tab paths are absolute', () {
      for (final tab in bottomTabs) {
        expect(tab.path.startsWith('/'), isTrue, reason: tab.id);
      }
    });

    test('every screen maps to at least one feature id', () {
      final idPattern = RegExp(r'^V[123]-[A-Z]{2,4}-\d{2}$');
      for (final s in allScreens) {
        expect(s.featureIds, isNotEmpty, reason: s.id);
        for (final f in s.featureIds) {
          expect(idPattern.hasMatch(f), isTrue, reason: '${s.id}: $f');
        }
      }
    });

    test('no screen claims VERIFIED in the foundation build', () {
      for (final s in allScreens) {
        expect(s.status, isNot(FeatureStatus.verified), reason: s.id);
      }
    });

    test('all 15 planned screens from the brief are registered', () {
      final titles = allScreens.map((s) => s.title).toSet();
      expect(
        titles,
        containsAll(<String>[
          'Home',
          'Library',
          'Book Details',
          'Translation Workspace',
          'Translation Editor',
          'Custom Dictionary',
          'Custom Instructions',
          'AI Providers',
          'Tasks',
          'Export Manager',
          'OCR Workspace',
          'Proofreading',
          'Bilingual Reader',
          'Settings',
          'Help & Diagnostics',
        ]),
      );
    });
  });

  group('FeatureStatus', () {
    test('only VERIFIED is usable', () {
      for (final s in FeatureStatus.values) {
        expect(s.isUsable, s == FeatureStatus.verified, reason: s.code);
      }
    });

    test('codes match the Feature Matrix vocabulary', () {
      expect(
        FeatureStatus.values.map((s) => s.code),
        ['PLANNED', 'IN PROGRESS', 'IMPLEMENTED', 'VERIFIED', 'BLOCKED'],
      );
    });
  });
}

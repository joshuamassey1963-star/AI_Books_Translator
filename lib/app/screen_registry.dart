import 'package:flutter/material.dart';

import '../core/feature_status.dart';

/// Where a screen lives in the navigation tree.
enum ScreenPlacement { bottomTab, librarySub, moreSub }

/// Static description of one screen. The registry is the single source of
/// truth for navigation, so a screen can never be reachable without an
/// honest status attached to it.
@immutable
class AppScreen {
  const AppScreen({
    required this.id,
    required this.title,
    required this.path,
    required this.icon,
    required this.placement,
    required this.version,
    required this.status,
    required this.featureIds,
    required this.summary,
  });

  /// Stable screen id, e.g. `SCR-LIB`.
  final String id;
  final String title;

  /// Absolute route path for tabs; relative segment for sub-screens.
  final String path;
  final IconData icon;
  final ScreenPlacement placement;
  final ProductVersion version;
  final FeatureStatus status;

  /// Feature Matrix ids this screen will deliver.
  final List<String> featureIds;

  /// One-line description shown on the placeholder.
  final String summary;
}

/// Bottom navigation tabs (4-5 per roadmap section 2).
const List<AppScreen> bottomTabs = [
  AppScreen(
    id: 'SCR-HOME',
    title: 'Home',
    path: '/home',
    icon: Icons.home_outlined,
    placement: ScreenPlacement.bottomTab,
    version: ProductVersion.v1,
    status: FeatureStatus.inProgress,
    featureIds: ['V1-NAV-01', 'V1-NAV-03'],
    summary: 'New project, ongoing work, recent translations.',
  ),
  AppScreen(
    id: 'SCR-LIB',
    title: 'Library',
    path: '/library',
    icon: Icons.menu_book_outlined,
    placement: ScreenPlacement.bottomTab,
    version: ProductVersion.v1,
    status: FeatureStatus.planned,
    featureIds: ['V1-LIB-01', 'V1-IMP-01', 'V1-IMP-02'],
    summary: 'Bookshelf, import, book details and chapter navigator.',
  ),
  AppScreen(
    id: 'SCR-TRN',
    title: 'Translate',
    path: '/translate',
    icon: Icons.translate,
    placement: ScreenPlacement.bottomTab,
    version: ProductVersion.v1,
    status: FeatureStatus.planned,
    featureIds: ['V1-ENG-01', 'V1-AIP-01', 'V1-INS-01'],
    summary: 'Source/target language, AI provider, instructions, start.',
  ),
  AppScreen(
    id: 'SCR-TSK',
    title: 'Tasks',
    path: '/tasks',
    icon: Icons.playlist_play,
    placement: ScreenPlacement.bottomTab,
    version: ProductVersion.v1,
    status: FeatureStatus.planned,
    featureIds: ['V1-TSK-01', 'V1-TSK-02', 'V1-TSK-03'],
    summary: 'Queue, progress, errors, retry and checkpoints.',
  ),
  AppScreen(
    id: 'SCR-MORE',
    title: 'More',
    path: '/more',
    icon: Icons.more_horiz,
    placement: ScreenPlacement.bottomTab,
    version: ProductVersion.v1,
    status: FeatureStatus.inProgress,
    featureIds: ['V1-NAV-01'],
    summary: 'Workspace tools, settings and help.',
  ),
];

/// Sub-screen under Library.
const AppScreen bookDetailsScreen = AppScreen(
  id: 'SCR-BOOK',
  title: 'Book Details',
  path: 'book',
  icon: Icons.info_outline,
  placement: ScreenPlacement.librarySub,
  version: ProductVersion.v1,
  status: FeatureStatus.planned,
  featureIds: ['V1-LIB-02', 'V1-IMP-05'],
  summary: 'Metadata, chapters, fingerprint and import diagnostics.',
);

/// Sub-screens reachable from the More tab.
const List<AppScreen> moreScreens = [
  AppScreen(
    id: 'SCR-WSP',
    title: 'Translation Workspace',
    path: 'workspace',
    icon: Icons.view_column_outlined,
    placement: ScreenPlacement.moreSub,
    version: ProductVersion.v1,
    status: FeatureStatus.planned,
    featureIds: ['V1-ENG-01', 'V1-EDT-01'],
    summary: 'Chunk preview and chapter-by-chapter translation.',
  ),
  AppScreen(
    id: 'SCR-EDT',
    title: 'Translation Editor',
    path: 'editor',
    icon: Icons.edit_note,
    placement: ScreenPlacement.moreSub,
    version: ProductVersion.v1,
    status: FeatureStatus.planned,
    featureIds: ['V1-EDT-01', 'V1-EDT-02', 'V1-EDT-03'],
    summary: 'Side-by-side source and translation with review states.',
  ),
  AppScreen(
    id: 'SCR-DIC',
    title: 'Custom Dictionary',
    path: 'dictionary',
    icon: Icons.book_outlined,
    placement: ScreenPlacement.moreSub,
    version: ProductVersion.v1,
    status: FeatureStatus.planned,
    featureIds: ['V1-GLO-01', 'V1-GLO-02', 'V1-GLO-05'],
    summary: 'Glossary terms, protected terms, conflicts, import/export.',
  ),
  AppScreen(
    id: 'SCR-INS',
    title: 'Custom Instructions',
    path: 'instructions',
    icon: Icons.rule,
    placement: ScreenPlacement.moreSub,
    version: ProductVersion.v1,
    status: FeatureStatus.planned,
    featureIds: ['V1-INS-01', 'V1-INS-02'],
    summary: 'Tone, style, grammar, formatting and do-not-translate rules.',
  ),
  AppScreen(
    id: 'SCR-AIP',
    title: 'AI Providers',
    path: 'providers',
    icon: Icons.hub_outlined,
    placement: ScreenPlacement.moreSub,
    version: ProductVersion.v1,
    status: FeatureStatus.planned,
    featureIds: ['V1-AIP-01', 'V1-AIP-02', 'V1-AIP-03'],
    summary: 'API keys, base URL, model id, connection test.',
  ),
  AppScreen(
    id: 'SCR-EXP',
    title: 'Export Manager',
    path: 'export',
    icon: Icons.ios_share,
    placement: ScreenPlacement.moreSub,
    version: ProductVersion.v1,
    status: FeatureStatus.planned,
    featureIds: ['V1-EXP-01', 'V1-EXP-02', 'V1-EXP-03', 'V1-EXP-04'],
    summary: 'TXT, DOCX, EPUB and Unicode Hindi PDF export.',
  ),
  AppScreen(
    id: 'SCR-OCR',
    title: 'OCR Workspace',
    path: 'ocr',
    icon: Icons.document_scanner_outlined,
    placement: ScreenPlacement.moreSub,
    version: ProductVersion.v2,
    status: FeatureStatus.planned,
    featureIds: ['V2-OCR-01', 'V2-OCR-03'],
    summary: 'Scanned PDF and image OCR with a correction editor.',
  ),
  AppScreen(
    id: 'SCR-PRF',
    title: 'Proofreading',
    path: 'proofreading',
    icon: Icons.fact_check_outlined,
    placement: ScreenPlacement.moreSub,
    version: ProductVersion.v2,
    status: FeatureStatus.planned,
    featureIds: ['V2-QA-01', 'V2-QA-02'],
    summary: 'AI reviewer pass and automatic quality checks.',
  ),
  AppScreen(
    id: 'SCR-RDR',
    title: 'Bilingual Reader',
    path: 'reader',
    icon: Icons.chrome_reader_mode_outlined,
    placement: ScreenPlacement.moreSub,
    version: ProductVersion.v2,
    status: FeatureStatus.planned,
    featureIds: ['V2-RDR-01'],
    summary: 'Original/translation toggle with paragraph sync.',
  ),
  AppScreen(
    id: 'SCR-SET',
    title: 'Settings',
    path: 'settings',
    icon: Icons.settings_outlined,
    placement: ScreenPlacement.moreSub,
    version: ProductVersion.v1,
    status: FeatureStatus.planned,
    featureIds: ['V1-SET-01', 'V1-SEC-05'],
    summary: 'Privacy, consent, storage and app preferences.',
  ),
  AppScreen(
    id: 'SCR-HLP',
    title: 'Help & Diagnostics',
    path: 'help',
    icon: Icons.help_outline,
    placement: ScreenPlacement.moreSub,
    version: ProductVersion.v1,
    status: FeatureStatus.planned,
    featureIds: ['V1-ERR-01'],
    summary: 'Help, import diagnostics and error codes.',
  ),
];

/// Every screen in the app, for tests and docs.
const List<AppScreen> allScreens = [
  ...bottomTabs,
  bookDetailsScreen,
  ...moreScreens,
];

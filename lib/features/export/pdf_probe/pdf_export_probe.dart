import 'dart:typed_data';

import 'probe_cases.dart';

/// Font files handed to a probe engine. Fonts are fetched in CI (OFL, pinned
/// SHA-256) and are never committed to the repository.
class ProbeFontSet {
  const ProbeFontSet({
    required this.devanagari,
    this.devanagariBold,
    this.latinGreek,
    this.hebrew,
  });

  final Uint8List devanagari;
  final Uint8List? devanagariBold;
  final Uint8List? latinGreek;
  final Uint8List? hebrew;
}

/// One candidate Hindi PDF export engine (M2b-3). A probe only writes PDF
/// bytes; verification (render, extract, fonts) is done by independent tools.
abstract interface class PdfExportProbe {
  /// Short id used in file names and reports, e.g. `engine_a_dart_pdf`.
  String get engineId;

  /// Renders [probeCase] into a new PDF. Never changes the case text.
  Future<Uint8List> render(ProbeCase probeCase, ProbeFontSet fonts);
}

/// M2b-3b-2a spike: HarfBuzz shaping output, as data. Produced on the host in
/// CI (uharfbuzz) for now; no native HarfBuzz in the app yet.
library;

/// One positioned glyph. Units are font units (see [ShapedRun.unitsPerEm]).
class ShapedGlyph {
  const ShapedGlyph({
    required this.glyphId,
    required this.cluster,
    required this.xAdvance,
    this.xOffset = 0,
    this.yOffset = 0,
  });

  /// Glyph index in the font (not a Unicode code point).
  final int glyphId;

  /// Index of the first source code point (rune) this glyph belongs to.
  final int cluster;
  final int xAdvance;
  final int xOffset;
  final int yOffset;
}

/// Glyphs drawn for one cluster, with the source text they stand for.
class GlyphCluster {
  const GlyphCluster({
    required this.start,
    required this.end,
    required this.text,
    required this.glyphs,
  });

  /// Source code point range `[start, end)`.
  final int start;
  final int end;

  /// Logical source text of the cluster (unchanged, in source order).
  final String text;

  /// Glyphs in visual order (may differ from source order, e.g. i-matra).
  final List<ShapedGlyph> glyphs;
}

class ShapedRunException implements Exception {
  ShapedRunException(this.message);
  final String message;
  @override
  String toString() => 'ShapedRunException: $message';
}

/// A left-to-right shaped run of [text]. RTL is out of scope for the spike.
class ShapedRun {
  ShapedRun({
    required this.text,
    required List<ShapedGlyph> glyphs,
    required this.unitsPerEm,
  }) : glyphs = List.unmodifiable(glyphs);

  final String text;
  final List<ShapedGlyph> glyphs;
  final int unitsPerEm;

  /// Groups glyphs into clusters and maps each to its source text.
  ///
  /// A glyph is never assumed to be one character: a cluster may hold several
  /// glyphs (कि = i-matra glyph + क) and several code points. Throws
  /// [ShapedRunException] for a cluster outside the text, non-monotonic
  /// clusters, or source code points that no glyph covers.
  List<GlyphCluster> clusters() {
    final runes = text.runes.toList();
    if (runes.isEmpty) {
      throw ShapedRunException('empty text');
    }
    if (glyphs.isEmpty) {
      throw ShapedRunException('no glyphs for non-empty text');
    }
    if (unitsPerEm <= 0) {
      throw ShapedRunException('unitsPerEm must be positive');
    }
    final groups = <List<ShapedGlyph>>[];
    var last = -1;
    for (final g in glyphs) {
      if (g.cluster < 0 || g.cluster >= runes.length) {
        throw ShapedRunException(
          'glyph ${g.glyphId} has cluster ${g.cluster} outside the text',
        );
      }
      if (g.cluster < last) {
        throw ShapedRunException('clusters not monotonic (LTR only)');
      }
      if (g.cluster == last) {
        groups.last.add(g);
      } else {
        groups.add([g]);
      }
      last = g.cluster;
    }
    if (groups.first.first.cluster != 0) {
      throw ShapedRunException('code points before the first cluster unmapped');
    }
    final result = <GlyphCluster>[];
    for (var i = 0; i < groups.length; i++) {
      final start = groups[i].first.cluster;
      final end = i + 1 < groups.length
          ? groups[i + 1].first.cluster
          : runes.length;
      result.add(
        GlyphCluster(
          start: start,
          end: end,
          text: String.fromCharCodes(runes.sublist(start, end)),
          glyphs: List.unmodifiable(groups[i]),
        ),
      );
    }
    return result;
  }
}

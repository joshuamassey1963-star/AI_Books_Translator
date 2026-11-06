import 'legacy_font_converter.dart';

/// Kruti Dev 010 → Unicode Devanagari (M2b-2a, D-026).
///
/// Port of the 7-pass byte transducer in SIL International's
/// `KrutiDev010.map` v1.3 (wsresources, MIT licence; see
/// `third_party/SIL_WSRESOURCES_LICENSE`). No font files are used.
///
/// Deliberate differences from the SIL map (documented in D-026):
/// - Bytes 140 (`Œ`) and 229 (`å`) are *not* mapped: SIL and other public
///   tables disagree (Devanagari zero vs. abbreviation sign). Byte 219
///   (`Û`, SIL's default/bullet) is not mapped either. They are reported.
/// - Positional variants 162 (ekar) and 170 (tent-r) are mapped to their
///   base forms in every context, not only after the listed consonants.
/// - Half consonant + low r + aakar becomes full consonant + low r + aakar.
/// - ZWJ/ZWNJ that the transducer inserts after a virama are removed, so
///   the output is plain searchable Unicode (input ZWJ/ZWNJ cannot occur:
///   they are outside the code page and reported).
class KrutiDev010Converter implements LegacyFontConverter {
  const KrutiDev010Converter();

  @override
  String get id => 'krutidev010';

  @override
  Set<String> get fontNames => const {
    'krutidev010',
    'krutidev010bold',
    'krutidev010italic',
    'krutidev010bolditalic',
  };

  @override
  (String, List<LegacyWarning>) convertRaw(String input) {
    final warnings = <LegacyWarningCode, Map<String, int>>{};
    void warn(LegacyWarningCode code, String ch) {
      final m = warnings.putIfAbsent(code, () => <String, int>{});
      m[ch] = (m[ch] ?? 0) + 1;
    }

    var b = <int>[for (final r in input.runes) _toByte(r)];
    b = _pass3(_pass2(_pass1(_pass0(b))));
    b = _pass4(b);
    b = _pass5(b, () => warn(LegacyWarningCode.ikarWithoutConsonant, 'f'));
    final out = _pass6(b, warn);
    final list = [
      for (final e in warnings.entries)
        for (final c in e.value.entries)
          LegacyWarning(e.key, c.key, count: c.value),
    ];
    return (out, list);
  }

  // ---- byte classes (from the SIL map) ----
  static const _ikar = 102, _nukta = 43, _reph = 90, _vb = 107;
  static const _hcOnly = [34, 39, 46, 47, 63, 70, 91, 184];
  static const _fcOnly = ['ष', 'श', 'ण', 'ध', 'घ', 'थ', 'ख', 'य'];
  static const _hcOnlySpecial = [159, 218, 123];
  static const _hcAlsoSpecial = [153, 171];
  static const _hcAlso = [
    67, 68, 69, 72, 73, 182, 76, 79, 80, 82, 84, 85, 88, 89, 184, 186, 214, //
  ];
  static const _fcAlsoBytes = [
    99, 100, 101, 210, 105, 81, 108, 111, 112, 114, 116, 117, 120, 121, 59, //
    103, 62,
  ];
  static const _fcAlsoUni = [
    'ब', 'क', 'म', 'भ', 'प', 'फ', 'स', 'व', 'च', 'त', 'ज', 'न', 'ग', 'ल', //
    'य', 'ह', 'झ',
  ];
  static const _fcAll = {
    59, 60, 62, 66, 71, 77, 78, 81, 86, 99, 100, 101, 103, 105, 106, 108, //
    110, 111, 112, 114, 116, 117, 120, 121, 165, 179, 196, 210, 211,
  };
  static const _scAll = {
    41, 61, 74, 75, 124, 125, 163, 193, 204, 205, 206, 207, 212, 216, 221, //
    224, 225, 227, 228, 230, 233, 240, 243, 244, 152,
  };
  static const _depVowel = {37, 104, 83, 96, 164, 119, 107, 115, 113, 168, 169};
  static const _nasal = {97, 161, 87};
  static const _postCons = {122, 170, 43};
  static final _hcAll = {
    ..._hcOnly,
    ..._hcOnlySpecial,
    ..._hcAlsoSpecial,
    ..._hcAlso,
  };

  /// Windows-1252 0x80–0x9F printable characters → byte.
  static const _cp1252 = {
    0x20AC: 0x80, 0x201A: 0x82, 0x0192: 0x83, 0x201E: 0x84, 0x2026: 0x85, //
    0x2020: 0x86, 0x2021: 0x87, 0x02C6: 0x88, 0x2030: 0x89, 0x0160: 0x8A,
    0x2039: 0x8B, 0x0152: 0x8C, 0x017D: 0x8E, 0x2018: 0x91, 0x2019: 0x92,
    0x201C: 0x93, 0x201D: 0x94, 0x2022: 0x95, 0x2013: 0x96, 0x2014: 0x97,
    0x02DC: 0x98, 0x2122: 0x99, 0x0161: 0x9A, 0x203A: 0x9B, 0x0153: 0x9C,
    0x017E: 0x9E, 0x0178: 0x9F,
  };

  /// Code points outside the code page are carried as `0x10000 + rune` so
  /// no pass matches them and pass 6 emits them unchanged with a warning.
  static int _toByte(int rune) {
    if (rune <= 0xFF) return rune;
    return _cp1252[rune] ?? 0x10000 + rune;
  }

  static String _fromByte(int b) {
    if (b >= 0x10000) return String.fromCharCode(b - 0x10000);
    for (final e in _cp1252.entries) {
      if (e.value == b) return String.fromCharCode(e.key);
    }
    return String.fromCharCode(b);
  }

  static int? _at(List<int> b, int i) => i < b.length ? b[i] : null;

  // Pass 0: nasal before a dependent vowel moves after it.
  static List<int> _pass0(List<int> b) {
    final o = <int>[];
    for (var i = 0; i < b.length; i++) {
      final next = _at(b, i + 1);
      if (_nasal.contains(b[i]) && next != null && _depVowel.contains(next)) {
        o
          ..add(next)
          ..add(b[i]);
        i++;
      } else {
        o.add(b[i]);
      }
    }
    return o;
  }

  static const _dup = {
    147: 39, 148: 39, 145: 34, 146: 34, 167: 164, 174: 168, 180: 165, //
    203: 47, 209: 151, 144: 210, 217: 159, 231: 193, 232: 47, 234: 205,
    235: 206, 236: 207, 237: 204, 238: 211, 239: 212, 245: 155, 246: 152,
    247: 214, 248: 191,
  };

  // Pass 1: duplicate glyphs → one form; repeated nasals collapse.
  static List<int> _pass1(List<int> b) {
    final o = <int>[];
    for (final raw in b) {
      final x = _dup[raw] ?? raw;
      if (_nasal.contains(x) && o.isNotEmpty && o.last == x) continue;
      o.add(x);
    }
    return o;
  }

  // Pass 2: half form + vertical bar, matra combinations.
  static List<int> _pass2(List<int> b) {
    final o = <int>[];
    var i = 0;
    while (i < b.length) {
      final x = b[i];
      final n1 = _at(b, i + 1), n2 = _at(b, i + 2);
      final hcAlsoIdx = _hcAlso.indexOf(x);
      if (x == _vb && n1 == 87 && n2 == 97) {
        o.addAll([_vb, 161]);
        i += 3;
      } else if (hcAlsoIdx >= 0 && n1 == 122 && n2 == _vb) {
        o.addAll([_fcAlsoBytes[hcAlsoIdx], 122, _vb]);
        i += 3;
      } else if (hcAlsoIdx >= 0 && n1 == _vb) {
        o.add(_fcAlsoBytes[hcAlsoIdx]);
        i += 2;
      } else if (x == 171 && n1 == _vb) {
        o.add(61);
        i += 2;
      } else if (x == 153 && n1 == _vb) {
        o.add(233);
        i += 2;
      } else if ((_hcOnly.contains(x) || _hcOnlySpecial.contains(x)) &&
          (n1 == _vb || n1 == 168 || n1 == 169)) {
        o.addAll([x, _vb, if (n1 == 168) 115, if (n1 == 169) 83]);
        i += 2;
      } else if (x == _vb && n1 == 115) {
        o.add(168);
        i += 2;
      } else if (x == _vb && n1 == 83) {
        o.add(169);
        i += 2;
      } else if (x == 98 && n1 == _reph) {
        o.add(195);
        i += 2;
      } else if (x == 87 && n1 == 97) {
        o.add(161);
        i += 2;
      } else if (x == _vb && n1 == 87) {
        o.add(130);
        i += 2;
      } else {
        o.add(x);
        i++;
      }
    }
    return o;
  }

  static const _unpack = {
    162: [115], 170: [122], 35: [106, 113], 58: [106, 119], //
    150: [110, 96], 151: [100, 96], 226: [103, 96], 198: [102, 90],
    199: [102, 97], 200: [104, 97], 201: [102, 90, 97], 202: [104, 90],
    155: [83, 90, 97], 177: [90, 97],
  };

  // Pass 3: positional variants and combined glyphs unpacked.
  static List<int> _pass3(List<int> b) => [
    for (final x in b) ...(_unpack[x] ?? [x]),
  ];

  /// End index of a consonant cluster starting at [j], or null:
  /// `HC* (C | HC VERTBAR) PC?`.
  static int? _cons(List<int> b, int j) {
    var k = j;
    while (k < b.length && _hcAll.contains(b[k])) {
      k++;
    }
    int e;
    if (k < b.length && (_fcAll.contains(b[k]) || _scAll.contains(b[k]))) {
      e = k + 1;
    } else if (k > j && k < b.length && b[k] == _vb) {
      e = k + 1;
    } else {
      return null;
    }
    if (e < b.length && _postCons.contains(b[e])) e++;
    return e;
  }

  // Pass 4: ikar + reph/nasal + cluster → ikar + cluster + reph + nasal.
  static List<int> _pass4(List<int> b) {
    final o = <int>[];
    var i = 0;
    while (i < b.length) {
      if (b[i] == _ikar) {
        var j = i + 1;
        final pre = <int>[];
        if (_at(b, j) == _reph) pre.add(b[j++]);
        if (j < b.length && _nasal.contains(b[j])) pre.add(b[j++]);
        if (pre.isNotEmpty) {
          final e = _cons(b, j);
          if (e != null) {
            o
              ..add(_ikar)
              ..addAll(b.sublist(j, e))
              ..addAll(pre);
            i = e;
            continue;
          }
        }
      }
      o.add(b[i++]);
    }
    return o;
  }

  // Pass 5: visual order → Unicode order:
  // ikar? cons nukta? vowel? reph? nasal? → reph cons nukta ikar vowel nasal.
  static List<int> _pass5(List<int> b, void Function() strayIkar) {
    final o = <int>[];
    var i = 0;
    while (i < b.length) {
      var j = i;
      final hasIkar = b[j] == _ikar;
      if (hasIkar) j++;
      final e = _cons(b, j);
      if (e != null) {
        var k = e;
        int? take(bool Function(int) test) {
          if (k < b.length && test(b[k])) return b[k++];
          return null;
        }

        final nukta = take((x) => x == _nukta);
        final vowel = take(_depVowel.contains);
        final reph = take((x) => x == _reph);
        final nasal = take(_nasal.contains);
        o.addAll([
          ?reph,
          ...b.sublist(j, e),
          ?nukta,
          if (hasIkar) _ikar,
          ?vowel,
          ?nasal,
        ]);
        i = k;
        continue;
      }
      if (hasIkar) strayIkar();
      o.add(b[i++]);
    }
    return o;
  }

  static const _v = '्';
  static const _zwj = '\u200D';
  static const _zwnj = '\u200C';

  static final Map<int, String> _single = () {
    final m = <int, String>{};
    for (var x = 48; x <= 57; x++) {
      m[x] = String.fromCharCode(x);
    }
    const devDigits = '१२३४५६७८९';
    for (var k = 0; k < 9; k++) {
      m[131 + k] = devDigits[k];
    }
    void zip(List<int> bytes, String chars) {
      final cs = chars.runes.toList();
      assert(bytes.length == cs.length);
      for (var k = 0; k < bytes.length; k++) {
        m[bytes[k]] = String.fromCharCode(cs[k]);
      }
    }

    zip([
      33, 36, 38, 40, 45, 92, 93, 94, 64, 187, 188, 189, 42, 190, 191, 192, //
      65, 222, 223,
    ], '!+-;.?,‘/÷()’={}।”“');
    zip([
      37, 43, 59, 60, 62, 66, 71, 77, 78, 81, 86, 99, 100, 101, 103, 105, //
      106, 108, 110, 111, 112, 114, 116, 117, 120, 121, 165, 179, 196, 210,
    ], 'ः़यढझठळडछफटबकमहपरसदवचतजनगलञङघभ');
    zip([
      118, 98, 195, 109, 197, 95, 44, 102, 104, 113, 119, 96, 115, 83, 168, //
      169, 183, 87, 97, 161, 107, 164, 130,
    ], 'अइईउऊऋएिीुूृेैोौऽॅंँाॄॉ');
    m.addAll({
      41: 'द्ध', 61: 'त्र', 74: 'श्र', 75: 'ज्ञ', 90: 'र$_v', 122: '$_vर', //
      193: 'प्र', 123: 'क्ष$_v$_zwj', 124: 'द्य', 125: 'द्व', 126: '$_v$_zwnj',
      153: 'न्न$_v$_zwj', 163: 'ख्र', 171: 'त्र$_v', 204: 'द्द', 205: 'ट्ट',
      206: 'ट्ठ', 207: 'ड्ड', 211: 'य$_v', 212: 'ड्ढ', 216: 'क्र', 221: 'फ्र',
      224: 'ह्न', 225: 'ह्य', 227: 'ह्म', 228: 'क्त', 230: 'द्र', 233: 'न्न',
      240: 'ठ्ठ', 243: 'स$_v$_zwjत्र', 244: 'क्क', 152: 'द्भ',
      159: 'त्त$_v', 218: 'र$_v$_zwj', 220: 'श$_v',
    });
    for (var k = 0; k < _hcOnly.length; k++) {
      m.putIfAbsent(_hcOnly[k], () => '${_fcOnly[k]}$_v$_zwj');
    }
    for (var k = 0; k < _hcAlso.length; k++) {
      m.putIfAbsent(_hcAlso[k], () => '${_fcAlsoUni[k]}$_v$_zwj');
    }
    return m;
  }();

  static final Map<(int, int), String> _pair = () {
    final m = <(int, int), String>{
      (44, 115): 'ऐ',
      (65, 65): '॥',
      (118, 107): 'आ',
      (118, 168): 'ओ',
      (118, 169): 'औ',
      (123, 107): 'क्ष',
      (159, 107): 'त्त',
      (120, 122): 'ग्र',
      (101, 122): 'म्र',
      (99, 122): 'ब्र',
    };
    for (var k = 0; k < _hcOnly.length; k++) {
      m[(_hcOnly[k], _vb)] = _fcOnly[k];
    }
    for (var k = 0; k < _hcAlso.length; k++) {
      m.putIfAbsent((_hcAlso[k], _nukta), () => '${_fcAlsoUni[k]}़$_v$_zwj');
    }
    return m;
  }();

  static bool _isDigitByte(int x) =>
      (x >= 48 && x <= 57) || (x >= 131 && x <= 139);

  // Pass 6: bytes → Unicode; unknown codes are kept and reported.
  static String _pass6(
    List<int> b,
    void Function(LegacyWarningCode, String) warn,
  ) {
    final out = StringBuffer();
    for (var i = 0; i < b.length; i++) {
      final x = b[i];
      final next = _at(b, i + 1);
      final pair = next == null ? null : _pair[(x, next)];
      if (pair != null) {
        out.write(pair);
        i++;
      } else if (x == 37 && i > 0 && _isDigitByte(b[i - 1])) {
        out.write(':');
      } else if (x <= 32) {
        out.writeCharCode(x);
      } else if (_single[x] case final s?) {
        out.write(s);
      } else {
        final ch = _fromByte(x);
        warn(
          x >= 0x10000
              ? LegacyWarningCode.characterOutsideCodePage
              : LegacyWarningCode.unmappedCharacter,
          ch,
        );
        out.write(ch);
      }
    }
    return out.toString().replaceAll(_zwj, '').replaceAll(_zwnj, '');
  }
}

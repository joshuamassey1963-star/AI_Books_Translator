import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'pdf_export_probe.dart';
import 'probe_cases.dart';

/// Engine B (M2b-3b-1 prototype): Android's native text shaping (Minikin +
/// HarfBuzz) drawn into `android.graphics.pdf.PdfDocument` through a method
/// channel. Fonts come from the Android system fallback chain, so
/// [ProbeFontSet] is ignored; the PDF names the fonts it used.
///
/// Android only. iOS has no handler yet (a separate later evaluation), so
/// [render] throws [UnsupportedError] there.
class AndroidNativePdfEngine implements PdfExportProbe {
  const AndroidNativePdfEngine({
    MethodChannel channel = const MethodChannel(channelName),
  }) : _channel = channel;

  static const String channelName = 'ai_book_translator/pdf_probe';

  final MethodChannel _channel;

  @override
  String get engineId => 'engine_b_android_native';

  @override
  Future<Uint8List> render(ProbeCase probeCase, ProbeFontSet fonts) async {
    try {
      final bytes = await _channel.invokeMethod<Uint8List>('renderCase', {
        'id': probeCase.id,
        'rtl': probeCase.rtl,
        'blocks': [
          for (final b in probeCase.blocks)
            {'kind': b.kind.name, 'text': b.text},
        ],
      });
      if (bytes == null || bytes.isEmpty) {
        throw StateError('native engine returned no PDF for ${probeCase.id}');
      }
      return bytes;
    } on MissingPluginException {
      throw UnsupportedError(
        'Engine B needs the Android native PDF probe (not available here)',
      );
    }
  }

  /// App-specific external directory for probe output (no permission).
  Future<String?> outputDir() =>
      _channel.invokeMethod<String>('probeOutputDir');

  Future<Map<Object?, Object?>?> deviceInfo() =>
      _channel.invokeMethod<Map<Object?, Object?>>('deviceInfo');
}

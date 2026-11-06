import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A file chosen by the user through the system picker. Bytes are read only
/// on request, after the size has been checked against import limits.
class PickedTxtFile {
  const PickedTxtFile({
    required this.name,
    required this.size,
    required this.readBytes,
  });

  final String name;
  final int size;
  final Future<Uint8List> Function() readBytes;
}

/// Picker seam so tests can use a fake (M-DEV-02a).
abstract interface class TxtFilePicker {
  /// Returns `null` when the user cancels.
  Future<PickedTxtFile?> pickTxt();
}

/// System document picker (Android `ACTION_OPEN_DOCUMENT`, iOS document
/// picker). Needs no storage permission; access is limited to the one file
/// the user chooses. Nothing is uploaded or written back.
class SystemTxtFilePicker implements TxtFilePicker {
  const SystemTxtFilePicker();

  static const _textGroup = XTypeGroup(
    label: 'Text',
    extensions: ['txt'],
    mimeTypes: ['text/plain'],
    uniformTypeIdentifiers: ['public.plain-text'],
  );

  @override
  Future<PickedTxtFile?> pickTxt() async {
    final file = await openFile(acceptedTypeGroups: const [_textGroup]);
    if (file == null) return null;
    return PickedTxtFile(
      name: file.name,
      size: await file.length(),
      readBytes: file.readAsBytes,
    );
  }
}

final txtFilePickerProvider = Provider<TxtFilePicker>(
  (ref) => const SystemTxtFilePicker(),
);

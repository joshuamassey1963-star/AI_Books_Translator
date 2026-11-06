import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/legacy/legacy_font_converter.dart';
import '../engine/text/text_encoding.dart';
import 'dev_diagnostics.dart';

/// Developer Tests (DEV-01). Debug builds only: the route and the More
/// entry are guarded by `kDebugMode`, so release builds never include it.
/// Temporary diagnostic UI over existing engines; not the book reader.
class DevTestsScreen extends StatelessWidget {
  const DevTestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Developer Tests'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(key: ValueKey('dev-tab-encoding'), text: 'Text Encoding'),
              Tab(key: ValueKey('dev-tab-kruti'), text: 'Kruti Dev'),
              Tab(key: ValueKey('dev-tab-parser'), text: 'TXT Parser'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_EncodingTab(), _KrutiTab(), _ParserTab()],
        ),
      ),
    );
  }
}

const _maxInputChars = 20000;

Widget _row(String label, String value, {Key? key}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 2),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 130,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      Expanded(child: SelectableText(value, key: key)),
    ],
  ),
);

Widget _box(String title, String text, {Key? key}) => Card(
  child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        SelectableText(text.isEmpty ? '(empty)' : text, key: key),
      ],
    ),
  ),
);

const _note = Padding(
  padding: EdgeInsets.only(bottom: 8),
  child: Text(
    'Debug only. Synthetic input; nothing is saved, logged or uploaded.',
    style: TextStyle(fontStyle: FontStyle.italic),
  ),
);

class _SampleControls extends StatelessWidget {
  const _SampleControls({
    required this.controller,
    required this.sample,
    required this.encodingOverride,
    required this.onSample,
    required this.onOverride,
    required this.prefix,
  });

  final TextEditingController controller;
  final SampleBytes sample;
  final TextEncoding? encodingOverride;
  final ValueChanged<SampleBytes> onSample;
  final ValueChanged<TextEncoding?> onOverride;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: ValueKey('$prefix-input'),
          controller: controller,
          maxLength: _maxInputChars,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Sample text',
            border: OutlineInputBorder(),
          ),
        ),
        DropdownButtonFormField<SampleBytes>(
          key: ValueKey('$prefix-sample'),
          initialValue: sample,
          decoration: const InputDecoration(labelText: 'Encode text as'),
          items: [
            for (final s in SampleBytes.values)
              DropdownMenuItem(value: s, child: Text(s.label)),
          ],
          onChanged: (v) => onSample(v ?? sample),
        ),
        DropdownButtonFormField<TextEncoding?>(
          key: ValueKey('$prefix-override'),
          initialValue: encodingOverride,
          decoration: const InputDecoration(
            labelText: 'Explicit encoding (override)',
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('Auto-detect')),
            for (final e in TextEncoding.values)
              DropdownMenuItem(value: e, child: Text(e.label)),
          ],
          onChanged: onOverride,
        ),
      ],
    );
  }
}

class _EncodingTab extends StatefulWidget {
  const _EncodingTab();

  @override
  State<_EncodingTab> createState() => _EncodingTabState();
}

class _EncodingTabState extends State<_EncodingTab> {
  final _input = TextEditingController(text: 'भारत India 2026');
  SampleBytes _sample = SampleBytes.utf8;
  TextEncoding? _override;
  EncodingDiagnostics? _result;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final rep = r?.report;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _note,
        _SampleControls(
          controller: _input,
          sample: _sample,
          encodingOverride: _override,
          onSample: (v) => setState(() => _sample = v),
          onOverride: (v) => setState(() => _override = v),
          prefix: 'enc',
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const ValueKey('enc-run'),
          onPressed: () => setState(
            () => _result = inspectEncoding(
              _sample.encode(_input.text),
              override: _override,
            ),
          ),
          child: const Text('Inspect encoding'),
        ),
        if (r != null && rep != null) ...[
          const SizedBox(height: 12),
          _row('Bytes', '${r.byteCount}'),
          _row('Status', rep.status.name, key: const ValueKey('enc-status')),
          _row('Encoding', rep.encoding?.label ?? '—'),
          _row('Chosen by', rep.source?.name ?? '—'),
          _row('BOM', rep.hadBom ? 'yes' : 'no'),
          _row(
            'Issues',
            rep.issues.isEmpty ? 'none' : rep.issues.join(', '),
            key: const ValueKey('enc-issues'),
          ),
          if (rep.text != null) ...[
            _box(
              'Original decoded text',
              rep.text!,
              key: const ValueKey('enc-original'),
            ),
            _box(
              'NFC text (display only; already NFC: ${r.wasNfc})',
              r.nfcText!,
            ),
          ] else
            _box(
              'Lossy preview (display only)',
              const EncodingDetector()
                  .preview(_sample.encode(_input.text), encoding: _override)
                  .text,
            ),
        ],
      ],
    );
  }
}

class _KrutiTab extends StatefulWidget {
  const _KrutiTab();

  @override
  State<_KrutiTab> createState() => _KrutiTabState();
}

class _KrutiTabState extends State<_KrutiTab> {
  final _input = TextEditingController();
  String _font = devLegacyFontChoices.first;
  bool _confirmed = false;
  LegacyConversionResult? _result;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _note,
        const Text('Examples from passing tests:'),
        Wrap(
          spacing: 8,
          children: [
            for (final e in devKrutiExamples.keys)
              ActionChip(
                key: ValueKey('kruti-example-$e'),
                label: Text(e),
                onPressed: () => setState(() {
                  _input.text = e;
                  _result = null;
                }),
              ),
          ],
        ),
        TextField(
          key: const ValueKey('kruti-input'),
          controller: _input,
          maxLength: _maxInputChars,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Kruti Dev 010 encoded text',
            border: OutlineInputBorder(),
          ),
        ),
        DropdownButtonFormField<String>(
          key: const ValueKey('kruti-font'),
          initialValue: _font,
          decoration: const InputDecoration(labelText: 'Source font'),
          items: [
            for (final f in devLegacyFontChoices)
              DropdownMenuItem(value: f, child: Text(f)),
          ],
          onChanged: (v) => setState(() {
            _font = v ?? _font;
            _confirmed = false;
          }),
        ),
        CheckboxListTile(
          key: const ValueKey('kruti-confirm'),
          contentPadding: EdgeInsets.zero,
          value: _confirmed,
          onChanged: (v) => setState(() => _confirmed = v ?? false),
          title: Text('I confirm the text was typed in "$_font"'),
        ),
        FilledButton(
          key: const ValueKey('kruti-convert'),
          onPressed: () => setState(
            () => _result = convertLegacy(
              _input.text,
              fontName: _font,
              confirmed: _confirmed,
            ),
          ),
          child: const Text('Convert'),
        ),
        if (r != null) ...[
          const SizedBox(height: 12),
          _box('Original input (unchanged)', r.original),
          if (r.refusal != null)
            _row(
              'Refused',
              r.refusal!.name,
              key: const ValueKey('kruti-refusal'),
            )
          else ...[
            _box(
              'Unicode output',
              r.converted!,
              key: const ValueKey('kruti-output'),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('kruti-copy'),
                icon: const Icon(Icons.copy),
                label: const Text('Copy output'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: r.converted!));
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Copied')));
                },
              ),
            ),
          ],
          _row(
            'Warnings',
            r.warnings.isEmpty ? 'none' : r.warnings.join(', '),
            key: const ValueKey('kruti-warnings'),
          ),
          _row('Converter', r.converterId ?? '—'),
        ],
      ],
    );
  }
}

class _ParserTab extends StatefulWidget {
  const _ParserTab();

  @override
  State<_ParserTab> createState() => _ParserTabState();
}

class _ParserTabState extends State<_ParserTab> {
  final _input = TextEditingController(
    text: 'Chapter 1\n\nभारत एक देश है।\n\nChapter 2\n\nSecond part.',
  );
  SampleBytes _sample = SampleBytes.utf8;
  TextEncoding? _override;
  ParseDiagnostics? _result;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _note,
        _SampleControls(
          controller: _input,
          sample: _sample,
          encodingOverride: _override,
          onSample: (v) => setState(() => _sample = v),
          onOverride: (v) => setState(() => _override = v),
          prefix: 'txt',
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const ValueKey('txt-run'),
          onPressed: () => setState(
            () => _result = parseForDiagnostics(
              _sample.encode(_input.text),
              fileName: 'sample.txt',
              textEncoding: _override,
            ),
          ),
          child: const Text('Parse as TXT file'),
        ),
        if (r != null) ...[
          const SizedBox(height: 12),
          _row('Bytes', '${r.byteCount}'),
          if (r.ok) ...[
            _row('Status', 'parsed', key: const ValueKey('txt-status')),
            _row('Format', r.format!),
            _row('Title', r.title!),
            _row('Chapters', '${r.chapters}'),
            _row('Paragraphs', '${r.paragraphs}'),
            _row('SHA-256', r.sha256!.substring(0, 16)),
            _row(
              'Warnings',
              r.warnings.isEmpty ? 'none' : r.warnings.join(', '),
            ),
          ] else ...[
            _row(
              'Status',
              'refused: ${r.error!.code.name}',
              key: const ValueKey('txt-status'),
            ),
            _row('Message', r.error!.code.userMessage),
          ],
        ],
        const Divider(height: 32),
        const Text(
          'Not in this build (planned):',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const ListTile(
          key: ValueKey('dev-file-picker-disabled'),
          enabled: false,
          leading: Icon(Icons.folder_off_outlined),
          title: Text('Pick a TXT / EPUB / DOCX / PDF file'),
          subtitle: Text('Needs a scoped file picker – future checklist'),
        ),
        const ListTile(
          enabled: false,
          leading: Icon(Icons.picture_as_pdf_outlined),
          title: Text('PDF page count and extraction quality'),
          subtitle: Text('PDF not wired into the parser yet'),
        ),
      ],
    );
  }
}

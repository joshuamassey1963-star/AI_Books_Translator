/// Synthetic test text for the Hindi PDF export probe (M2b-3a).
///
/// All text is written for this project (no book content). Case ids map to
/// TEXT_ENCODING_FONT_COMPATIBILITY.md §4 (T01–T11) where they overlap.
library;

enum ProbeBlockKind { heading, paragraph }

class ProbeBlock {
  const ProbeBlock(this.kind, this.text);
  const ProbeBlock.p(this.text) : kind = ProbeBlockKind.paragraph;
  const ProbeBlock.h(this.text) : kind = ProbeBlockKind.heading;

  final ProbeBlockKind kind;
  final String text;
}

class ProbeCase {
  const ProbeCase({
    required this.id,
    required this.title,
    required this.blocks,
    this.tCases = const [],
    this.rtl = false,
  });

  /// File-safe id, e.g. `p01_matras`.
  final String id;

  /// English description (not rendered).
  final String title;
  final List<ProbeBlock> blocks;

  /// Related T-case ids from the compatibility doc.
  final List<String> tCases;

  /// Right-to-left paragraph (Hebrew).
  final bool rtl;

  /// The Unicode the PDF must give back, one block per line.
  String get expectedText => blocks.map((b) => b.text).join('\n');
}

const _zwj = '\u200D';
const _zwnj = '\u200C';

const String _longHindi =
    'यह एक लंबा अनुच्छेद है जिसका उद्देश्य पंक्ति तोड़ने और पृष्ठ बदलने की जाँच '
    'करना है। हिन्दी वाक्यों में मात्राएँ, संयुक्ताक्षर और विराम चिह्न सही क्रम में '
    'दिखाई देने चाहिए। अनुवादित पुस्तक का हर पृष्ठ पढ़ने योग्य होना चाहिए, और '
    'कॉपी किया गया पाठ मूल पाठ के समान होना चाहिए।';

final List<ProbeCase> probeCases = List.unmodifiable(<ProbeCase>[
  const ProbeCase(
    id: 'p01_paragraphs',
    title: 'Plain Hindi paragraphs',
    blocks: [
      ProbeBlock.p('भारत एक विशाल देश है। यहाँ अनेक भाषाएँ बोली जाती हैं।'),
      ProbeBlock.p('हिन्दी भारत की राजभाषा है।'),
    ],
  ),
  const ProbeCase(
    id: 'p02_mixed',
    title: 'English + Hindi mixed paragraph',
    tCases: ['T10'],
    blocks: [
      ProbeBlock.p(
        'यह Gospel of John 1:1 का अध्ययन है, जहाँ “Logos” शब्द आता है।',
      ),
      ProbeBlock.p('The book पुस्तक has 12 chapters और 340 pages.'),
    ],
  ),
  const ProbeCase(
    id: 'p03_matras',
    title: 'Vowel signs (matras), incl. i-matra reordering',
    tCases: ['T01', 'T02'],
    blocks: [
      ProbeBlock.p('का कि की कु कू कृ के कै को कौ कं कः कँ'),
      ProbeBlock.p('कि हिंदी स्थिति किताब निति'),
    ],
  ),
  const ProbeCase(
    id: 'p04_conjuncts_reph',
    title: 'Conjuncts, reph and rakar',
    tCases: ['T03', 'T05'],
    blocks: [
      ProbeBlock.p('क्ष त्र ज्ञ श्र द्ध द्व ह्म ह्य ट्ट ड्ड'),
      ProbeBlock.p('धर्म कर्म प्रकाश ट्रक क्रम पूर्ण'),
    ],
  ),
  const ProbeCase(
    id: 'p05_halant',
    title: 'Explicit halant (virama)',
    tCases: ['T04'],
    blocks: [
      ProbeBlock.p('क् ख् ग् वाक् जगत्'),
      ProbeBlock.p('विद्यालय सम्मान अक्षर'),
    ],
  ),
  const ProbeCase(
    id: 'p06_zwj_zwnj',
    title: 'ZWJ / ZWNJ half forms',
    tCases: ['T04'],
    blocks: [ProbeBlock.p('क्${_zwj}ष क्${_zwnj}ष विद्${_zwj}यालय')],
  ),
  const ProbeCase(
    id: 'p07_nukta',
    title: 'Nukta letters (NFC form)',
    tCases: ['T06', 'T11'],
    blocks: [ProbeBlock.p('क़ ख़ ग़ ज़ ड़ ढ़ फ़ पढ़ाई')],
  ),
  const ProbeCase(
    id: 'p08_digits_punct',
    title: 'Devanagari and Latin digits, punctuation, symbols',
    tCases: ['T08', 'T09'],
    blocks: [
      ProbeBlock.p('०१२३४५६७८९ 0123456789'),
      ProbeBlock.p('। ॥ “ ” ‘ ’ — – … ₹ %'),
    ],
  ),
  const ProbeCase(
    id: 'p09_vedic',
    title: 'Sanskrit / Vedic marks',
    tCases: ['T07'],
    blocks: [ProbeBlock.p('ॐ ऽ ॰ अ॑ अ॒')],
  ),
  const ProbeCase(
    id: 'p10_headings',
    title: 'Headings and paragraphs',
    blocks: [
      ProbeBlock.h('अध्याय १: प्रारम्भ'),
      ProbeBlock.p('पहला अनुच्छेद यहाँ है।'),
      ProbeBlock.h('भाग २'),
      ProbeBlock.p('दूसरा अनुच्छेद यहाँ है।'),
    ],
  ),
  const ProbeCase(
    id: 'p11_long_wrap',
    title: 'Long lines and page wrapping',
    blocks: [
      ProbeBlock.p(_longHindi),
      ProbeBlock.p(_longHindi),
      ProbeBlock.p(_longHindi),
      ProbeBlock.p(_longHindi),
      ProbeBlock.p(_longHindi),
      ProbeBlock.p(_longHindi),
    ],
  ),
  const ProbeCase(
    id: 'p12_latin_greek',
    title: 'Latin and Greek preservation',
    blocks: [
      ProbeBlock.p('In the beginning was the Word. Café, naïve, résumé.'),
      ProbeBlock.p('Ἐν ἀρχῇ ἦν ὁ λόγος. λόγος'),
    ],
  ),
  const ProbeCase(
    id: 'p13_hebrew',
    title: 'Hebrew preservation (RTL)',
    rtl: true,
    blocks: [ProbeBlock.p('בְּרֵאשִׁית בָּרָא אֱלֹהִים')],
  ),
]);

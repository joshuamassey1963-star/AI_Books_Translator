# Read Aloud / Text-to-Speech – Specification

Owner request: 2026-11-06 (Session 5). Status of every feature: **PLANNED**. Nothing here is implemented.
Feature IDs are also in `docs/FEATURE_MATRIX.md` (module *Read Aloud*, prefix `TTS`).

## Principles
1. **Translation and TTS are separate engines.** TTS consumes finished text; it never calls the translation engine and vice versa.
2. **Reads validated text only:** source = L2 corrected (else L1 Unicode-converted); translation = L4 edited (else L3). **Never L0 raw extraction**, never unvalidated OCR, never legacy-font glyph codes (D-016 layers).
3. **System TTS ≠ AI TTS.** UI labels them differently: "Device voice (offline, free)" vs. "Online AI voice (your API key, may cost money)".
4. BYOK for AI TTS: keys in Keystore/Keychain only (V1-SEC-01); never in source, logs, exports or crash reports; no hardcoded model names or prices; **never switch to a paid provider silently**; text sent only after consent (V1-SEC-03).
5. Robust playback: audio focus, interruptions (calls, other apps, headphones unplugged), app lifecycle, provider errors – each handled and tested.
6. Android and iOS speech engines are evaluated independently; voice availability is detected at runtime, never assumed.

## Platform notes (to be re-verified at implementation time)
| Topic | Android | iOS |
|---|---|---|
| Engine | `TextToSpeech` (engine chosen by user, e.g. Google Speech Services); Hindi `hi-IN` only if a Hindi voice is installed | `AVSpeechSynthesizer`; Hindi voice availability depends on installed voices |
| Max input per utterance | `getMaxSpeechInputLength()` (engine-specific) → chunking required | No hard documented limit, chunk anyway for resume/highlight |
| Background | Foreground service (media playback type) + media notification | `UIBackgroundModes: audio` + AVAudioSession category |
| Interruptions | Audio focus (`AudioFocusRequest`), `ACTION_AUDIO_BECOMING_NOISY` | AVAudioSession interruption/route-change notifications |
| Word progress | `UtteranceProgressListener.onRangeStart` (API 26+, engine-dependent) | `willSpeakRangeOfSpeechString` |
| Candidate packages | `flutter_tts` 4.2.5 (MIT), `audio_service` 0.18.19 (MIT), `audio_session` 0.2.4 (MIT), `just_audio` 0.10.6 (MIT/Apache-2.0, for AI audio files) – to be re-checked when added |

## Architecture sketch
`ReadAloudController` (queue of `SpeechSegment`s: id, layer, language tag, text, paragraph id) → `TtsEngine` interface → `SystemTtsEngine` (flutter_tts or channel) / `AiTtsEngine` (V2, provider adapters) → `PlaybackSession` (audio_service: notification, focus, lifecycle) → `ReadingPositionStore` (book id, layer, paragraph id, char offset). `TextSourceSelector` picks L2/L1 or L4/L3 and refuses layers not validated.

## Features

### V1-TTS-01 · `TtsEngine` interface + Android system TTS adapter (Hindi, English) · V1 · P1
- **Dependencies:** V1-ENC-03 (NFC), V1-STO-01.
- **Platform limits:** Hindi needs an installed Hindi voice; otherwise show "Hindi voice not installed – open TTS settings", never fall back to reading Hindi with an English voice silently.
- **Acceptance:** lists available voices per language; speaks Hindi and English sample texts; reports errors (engine missing, language unsupported).
- **Tests:** unit with fake engine (interface contract); Android device manual test (Hindi + English); integration_test on emulator for engine-missing path.
- **Status:** PLANNED.

### V1-TTS-02 · iOS native speech adapter (evaluated independently) · V1 · P1
- **Dependencies:** V1-TTS-01 interface.
- **Platform limits:** voices differ by iOS version and download state.
- **Acceptance:** same contract as V1-TTS-01 on iOS; documented results for Hindi/English on a real device or simulator.
- **Tests:** unit (shared contract tests); manual iOS device/simulator check.
- **Status:** PLANNED.

### V1-TTS-03 · Read original or translation from validated layers · V1 · P0 (safety)
- **Dependencies:** D-016 layers, V1-EDT-01, V1-LEG-03, V2-OCR-09.
- **Acceptance:** source reads L2→L1, translation reads L4→L3; L0, unvalidated OCR and unconverted legacy text are refused with a clear message; layer shown in player.
- **Tests:** unit for `TextSourceSelector` (all layer combinations); regression: legacy-font page never read raw (links RC-001/RC-002).
- **Status:** PLANNED.

### V1-TTS-04 · Reading scopes and segmentation · V1 · P1
- **Scope:** selection, paragraph, chapter, continuous (next chapter auto).
- **Dependencies:** V1-TTS-01, V1-IMP-04/07.
- **Platform limits:** utterance length limit → split by sentence (`।`, `?`, `!`, `.`), never inside a word or conjunct.
- **Acceptance:** each scope starts/stops at correct boundaries; no text skipped or repeated between chunks.
- **Tests:** unit for Hindi/English/mixed sentence splitter (danda, abbreviations, numbers, quotes); unit "concatenated chunks == source".
- **Status:** PLANNED.

### V1-TTS-05 · Playback controls, voice, speed, pitch · V1 · P1
- **Dependencies:** V1-TTS-01/04.
- **Acceptance:** play/pause/stop, previous/next paragraph, voice picker, speed and pitch sliders with engine-supported ranges; settings saved per language.
- **Tests:** widget tests with fake engine; unit for settings persistence.
- **Status:** PLANNED.

### V1-TTS-06 · Save and restore reading position · V1 · P1
- **Dependencies:** V1-STO-01, V1-TTS-04.
- **Acceptance:** position (book, layer, paragraph id, offset) saved on pause/stop/interruption/app kill; resume continues from that sentence; position survives text edits by anchoring to paragraph id.
- **Tests:** unit (position store, edit-anchoring); integration (kill and resume).
- **Status:** PLANNED.

### V1-TTS-07 · Background playback, notification controls, interruptions · V1 · P1
- **Dependencies:** V1-TTS-05, V1-STR-02 notification design.
- **Platform limits:** Android foreground service type + notification permission (Android 13+); iOS background audio mode. OEM battery killers on Android.
- **Acceptance:** continues with screen off; lock-screen/notification play/pause/next; pauses on phone call or other audio, resumes only if appropriate; pauses on headphone unplug; stops cleanly on app swipe-away; errors shown, not silent.
- **Tests:** unit for state machine (fake audio focus events); manual device checklist (call, alarm, Bluetooth disconnect, screen off 30 min).
- **Status:** PLANNED.

### V1-TTS-08 · Secure BYOK AI TTS configuration architecture (no real provider) · V1 · P2
- **Dependencies:** V1-AIP-02, V1-SEC-01, V1-SEC-03.
- **Acceptance:** provider profile (base URL, model id, voice id entered by user; no hardcoded names/prices); key in secure storage; "may cost money" label; paid use requires explicit opt-in per provider; system TTS stays default; no network call in V1.
- **Tests:** unit (key never in logs/exports – log scrubber test; no auto-switch logic); mock adapter contract test.
- **Status:** PLANNED.

### V1-TTS-09 · Mixed-script segments (Hindi with English words) · V1 · P2
- **Dependencies:** V1-TTS-04, V1-TRP-02.
- **Acceptance:** language tag per segment; English words inside Hindi read acceptably (configurable: Hindi voice for all vs. switch voice per run); digits read per digit policy.
- **Tests:** unit for script-run detection; manual listening check with sample sentences (T-strings in TEXT_ENCODING_FONT_COMPATIBILITY.md).
- **Status:** PLANNED.

### V2-TTS-01 · Real AI TTS provider integration · V2 · P1
- **Dependencies:** V1-TTS-08, V2-TTS-02, V2-TTS-06.
- **Acceptance:** user-chosen provider speaks a paragraph; consent shown first; cost/quota shown; failure falls back to device voice **only after asking**.
- **Tests:** adapter tests with mocked HTTP (200/401/402/429/5xx/timeout); manual with owner's own key (never committed).
- **Status:** PLANNED.

### V2-TTS-02 · Provider-specific API adapters · V2 · P1
- **Dependencies:** V1-AIP-01 adapter pattern.
- **Acceptance:** one adapter per provider; capabilities declared (voices, formats, max chars, streaming); no provider-specific code outside its adapter.
- **Tests:** contract tests per adapter with recorded synthetic responses.
- **Status:** PLANNED.

### V2-TTS-03 · Audio chunking, caching and resume · V2 · P1
- **Dependencies:** V2-TTS-01, V1-TTS-06.
- **Acceptance:** cache key = text hash + provider + model + voice + settings; no repeat billing for cached chunks; resume mid-chapter; cache size limit and clear option.
- **Tests:** unit (cache key, eviction); integration (resume without re-request).
- **Status:** PLANNED.

### V2-TTS-04 · Sentence/word highlighting where reliable · V2 · P2
- **Dependencies:** V1-TTS-04, engine progress callbacks / provider timestamps.
- **Platform limits:** word ranges are engine-dependent; Devanagari ranges may not align with grapheme clusters → fall back to sentence highlighting.
- **Acceptance:** highlight never points at wrong text; automatic fallback documented per engine.
- **Tests:** unit for range→grapheme mapping (conjuncts, matras); manual per engine.
- **Status:** PLANNED.

### V2-TTS-05 · Audio export and "My Recordings" · V2 · P2
- **Dependencies:** V2-TTS-03, V1-STO-04.
- **Acceptance:** export chapter audio (format per provider/device support); library of recordings with delete/share; exported files contain no keys; licence/terms reminder for provider audio.
- **Tests:** unit (metadata, no secrets in file); manual playback in other apps.
- **Status:** PLANNED.

### V2-TTS-06 · Explicit free/paid model and quota information · V2 · P1
- **Dependencies:** V1-AIP-* pricing rules (no hardcoded prices).
- **Acceptance:** cost/quota info comes from provider data or user entry, shown before use; usage counter; warning before limit; never auto-switch to paid.
- **Tests:** unit (no-auto-switch rule, warning thresholds).
- **Status:** PLANNED.

### V3-TTS-01 · Bilingual listening · V3 · P2
- Source and translation alternately per paragraph/sentence, separate voices. **Dependencies:** V1-TTS-03/04, V2-TTS-03. **Tests:** unit for interleaving order. **Status:** PLANNED.

### V3-TTS-02 · Multiple speakers/voices · V3 · P3
- Voice per character/dialogue using the character register (V1-ENG-08). **Dependencies:** V2-TTS-02. **Tests:** unit for speaker assignment. **Status:** PLANNED.

### V3-TTS-03 · Advanced voice customisation · V3 · P3
- Pronunciation dictionary, pauses, emphasis (SSML where supported). **Dependencies:** V2-TTS-02, V1-GLO-*. **Tests:** unit for SSML generation/escaping. **Status:** PLANNED.

## Milestones (proposed, see ROADMAP)
- **M10b** TTS-1: V1-TTS-01, V1-TTS-03, V1-TTS-04, V1-TTS-05 (Android system TTS, fake-engine tests).
- **M10c** TTS-2: V1-TTS-06, V1-TTS-07, V1-TTS-09 (position, background, interruptions).
- **M10d** TTS-3: V1-TTS-02 (iOS), V1-TTS-08 (BYOK architecture, no network).
- **M14a/b/c** V2: adapters + integration (V2-TTS-01/02/06) → caching/resume (V2-TTS-03) → highlighting/export (V2-TTS-04/05).
- **M22** V3: V3-TTS-01..03.

## Reference
Previous *All-in-One Document Reader* repo not accessible (HTTP 404 for Hark, 2026-11-06). No code copied; any future reuse needs inspection, compatibility tests and licence review.

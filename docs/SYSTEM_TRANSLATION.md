# System-Wide Translation – Specification

Owner request: 2026-11-06 (Session 5). Status of every feature: **PLANNED**. Nothing here is implemented.
Feature IDs are also in `docs/FEATURE_MATRIX.md` (module *System Translation*, prefix `STR`).

## Principles
1. **No universal cross-app access is promised.** Android and iOS each allow only specific, user-initiated entry points; every entry point is evaluated per platform.
2. **Accessibility is never required** for ordinary translation (paste, share, selected text, clipboard on demand). Accessibility-based features are V3, optional, with separate explicit consent.
3. Same translation engine as books (`V1-ENG-*`), same provider rules: BYOK, consent before sending text to a cloud provider (V1-SEC-03), no silent switch to a paid API, no keys or text in logs (V1-SEC-01/04).
4. Protected words, user dictionary and digit policy apply here too (V1-TRP-01..05, V1-GLO-*).
5. Snippet translations are stored locally as their own job type (source text, result, provider/model id, timestamp); user can delete them. No background clipboard reading, ever.
6. Store-policy and privacy review is a **gate before implementation** of every V2/V3 entry point (recorded in DECISIONS when done).

## Platform capability summary (to be re-verified at implementation time)
| Entry point | Android | iOS |
|---|---|---|
| Paste text in app | Yes | Yes |
| Share sheet → app | Yes: `ACTION_SEND` / `ACTION_SEND_MULTIPLE` intent filter (text, files) | Yes: Share Extension (separate target, tight memory limit, own lifecycle) |
| Selected text → app | `ACTION_PROCESS_TEXT` (API 23+): appears in the text-selection menu **only in apps whose text views offer it** | No general selected-text API; only Share/Action Extension where the host app offers sharing |
| Clipboard | Read only while app is in foreground (Android 10+ blocks background reads); user taps "Translate clipboard" | Paste permission prompt / paste control; user-triggered only |
| URL / article | Share URL or paste link; fetch + readability extraction | Same |
| Floating bubble | Possible with "Display over other apps" (`SYSTEM_ALERT_WINDOW`) granted by user in Settings; policy review needed | Not possible (no overlays over other apps) |
| Accessibility-based reading of other apps | Possible via AccessibilityService, but Google Play requires a Permission Declaration and prominent in-app disclosure + affirmative consent for non-accessibility-tool apps (Play Console Help, "Use of the AccessibilityService API") | Not available to third-party apps |

## Features

### V1-STR-01 · Paste-text translation · V1 · P1
- **Dependencies:** V1-ENG-02, V1-ENG-07, V1-AIP-01, V1-SEC-03, V1-TRP-01..05, V1-ENC-03 (NFC).
- **Platform limits:** none beyond provider/network.
- **Acceptance:** user pastes or types text (limit shown, e.g. 20 000 chars); paragraphs preserved 1:1 (no skipped paragraph, V1-ENG-07); protected words and dictionary honoured; result copy/share/save to history; cancel works; offline → clear message, text kept.
- **Tests:** unit (segmentation, paragraph count equal, protected words, NFC input); widget (paste → translate → copy); mock-provider error cases (401/429/timeout).
- **Status:** PLANNED.

### V1-STR-02 · Background translation execution and recovery · V1 · P1
- **Scope:** runs queued jobs (books and snippets) while the app is backgrounded and resumes after app kill/reboot. Queue states themselves are V1-TSK-01; checkpoints are V1-ENG-05 (not duplicated here).
- **Dependencies:** V1-TSK-01, V1-ENG-03..06, V1-ERR-01.
- **Platform limits:** Android: WorkManager / foreground service with user-visible notification (Android 14+ requires a declared foreground-service type), Doze and OEM battery killers. iOS: no unlimited background execution; only short background tasks (BGTaskScheduler) → jobs pause and resume on next launch; must be stated honestly in UI.
- **Acceptance:** progress persisted per chunk; force-stop mid-job → resume without re-billing completed chunks; notification shows progress and cancel (Android); iOS shows "paused while in background" instead of pretending to run.
- **Tests:** unit (checkpoint resume), integration on Android emulator (process kill), manual iOS device check.
- **Status:** PLANNED.

### V2-STR-01 · Android Share-to-Translate · V2 · P1
- **Dependencies:** V1-STR-01, V1-IMP-* (for shared files), V1-SEC-05.
- **Platform limits:** Android only; iOS equivalent is V2-STR-02.
- **Acceptance:** app appears in share sheet for `text/plain` (and supported book files); shared text opens the paste-translation screen pre-filled; shared files go through import hardening; nothing is sent to a provider before the user taps Translate.
- **Tests:** instrumentation test with a fake share intent; unit for MIME filtering; manual on 2 devices.
- **Candidate package:** `receive_sharing_intent` 1.9.0 (Apache-2.0) – evaluate vs. own platform channel.
- **Status:** PLANNED.

### V2-STR-02 · iOS Share Extension · V2 · P2
- **Dependencies:** V2-STR-01 design, V1-STR-01.
- **Platform limits:** separate extension target; strict memory/time limits; extension hands text to the main app (App Group) instead of translating inside the extension.
- **Acceptance:** text shared from Safari/Notes reaches the app; large text handled without extension crash.
- **Tests:** manual device test; unit for App-Group handoff parser.
- **Status:** PLANNED.

### V2-STR-03 · Android selected-text translation (`ACTION_PROCESS_TEXT`) · V2 · P1
- **Dependencies:** V1-STR-01.
- **Platform limits:** shows only in apps that expose the process-text menu; read-only and editable variants; not available on iOS (see V2-STR-04).
- **Acceptance:** "Translate (AI Book Translator)" in the selection menu of supporting apps; opens a compact translation sheet; optional "replace text" only for editable fields and only after user confirms.
- **Tests:** instrumentation (fake PROCESS_TEXT intent); manual in Chrome/Gmail/Notes-type apps; documented list of apps where it does not appear.
- **Status:** PLANNED.

### V2-STR-04 · iOS selected-text via Action Extension (evaluation) · V2 · P3
- **Dependencies:** V2-STR-02.
- **Platform limits:** only where the host app offers Share/Action for a selection; no system-wide selection API.
- **Acceptance:** evaluation report in RESEARCH.md; implement only if it gives value beyond V2-STR-02.
- **Tests:** manual device evaluation.
- **Status:** PLANNED.

### V2-STR-05 · User-triggered clipboard translation · V2 · P2
- **Dependencies:** V1-STR-01.
- **Platform limits:** Android 10+: clipboard readable only in foreground; iOS: system paste prompt / paste control. **No background monitoring.**
- **Acceptance:** button "Translate clipboard" reads clipboard once, on tap; shows preview before sending; never reads clipboard on app start automatically.
- **Tests:** unit (no read without user action – code path test); manual both platforms.
- **Status:** PLANNED.

### V2-STR-06 · URL / article import and translation · V2 · P2
- **Dependencies:** V1-STR-01, V1-ENC-01 (charset), V1-SEC-02 (HTML sanitising), INTERNET permission (planned M6).
- **Platform limits:** none specific; network required.
- **Acceptance:** user pastes/shares a URL; app fetches with size/time limits, extracts main text (readability-style), shows preview with source URL; respects paywalls (no bypass); unsafe HTML stripped; paragraphs aligned; article saved locally only if user chooses.
- **Tests:** unit with stored synthetic HTML fixtures (no copyrighted pages in repo); charset cases; redirect/timeout/oversize limits.
- **Status:** PLANNED.

### V2-STR-07 · Optional floating translation bubble (Android) · V2 · P3
- **Dependencies:** V1-STR-01, V2-STR-05, policy review (DECISIONS).
- **Platform limits:** Android only; requires user to grant "Display over other apps"; may be restricted by OEMs; not possible on iOS (UI must not show it there).
- **Acceptance:** off by default; enabling explains the permission; bubble translates clipboard/pasted text only on tap; easy to disable; no accessibility use.
- **Tests:** manual device tests; unit for permission-state handling.
- **Status:** PLANNED.

### V3-STR-01 · Optional accessibility-based translation (Android) · V3 · P3
- **Dependencies:** V2-STR-03, legal/policy review, separate consent screen.
- **Platform limits:** Android only. App is not an accessibility tool, so Play requires the AccessibilityService Permission Declaration, prominent in-app disclosure (separate from other disclosures) and affirmative consent; autonomous actions are prohibited. Not available on iOS.
- **Acceptance:** disabled by default; never required for any other feature; disclosure screen meets Play wording rules; reads only the text the user explicitly requests; no data stored or sent without action; full app works with the service off.
- **Tests:** manual + review checklist; unit for consent gating.
- **Status:** PLANNED (may be dropped if policy review is negative).

### V3-STR-02 · Advanced webpage translation with structure preservation · V3 · P2
- **Dependencies:** V2-STR-06, V1-TRP-01..05.
- **Platform limits:** in-app web view/reader only; does not inject into other browsers.
- **Acceptance:** headings, lists, links, tables kept; bilingual toggle; inline code/URLs protected.
- **Tests:** unit with synthetic HTML structure fixtures; golden tests.
- **Status:** PLANNED.

## Milestones (proposed, see ROADMAP)
- **M8b** (after M8 queue): V1-STR-01, V1-STR-02.
- **M13a** V2: V2-STR-01, V2-STR-03 (Android entry points) · **M13b** V2-STR-02/04 (iOS) · **M13c** V2-STR-05/06 · **M13d** V2-STR-07 (after policy review).
- **M21** V3: V3-STR-01 (only if policy review passes), V3-STR-02.

## Reference
The previous *All-in-One Document Reader* repo was **not readable** by Hark (GitHub App has no access, HTTP 404 on 2026-11-06). Its requirements are used only from the owner's description; no code is copied. If access is granted, any reuse needs inspection, compatibility tests and licence review first.

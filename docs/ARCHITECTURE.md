# Architecture

## Layers
```
lib/
  main.dart                 ProviderScope + app
  app/                      app widget, router (go_router), theme, screen registry
  core/                     shared types (FeatureStatus, errors, result types, utils)
  features/
    shell/                  bottom navigation shell
    home/  more/  planned/  Session-1 screens
    library/ import/ ...    (V1-B) data/ domain/ presentation/
    engine/                 (V1-C/D) pure Dart, no Flutter imports
      parser/ structure/ segmenter/ chunker/ glossary/ instructions/
      context/ providers/ queue/ recovery/ validator/ memory/ review/ export/
```
Each feature: `domain` (entities, repository interfaces, use cases) → `data` (Drift DAOs, file IO, HTTP adapters) → `presentation` (Riverpod providers + widgets). Dependencies point inward only.

## Navigation (roadmap §2)
Bottom tabs: **Home · Library · Translate · Tasks · More**. Library → Book Details. More → Translation Workspace, Translation Editor, Custom Dictionary, Custom Instructions, AI Providers, Export Manager, OCR Workspace (V2), Proofreading (V2), Bilingual Reader (V2), Settings, Help & Diagnostics. Tablets get a two-pane workspace later (V1-NAV-05). All screens are declared in `lib/app/screen_registry.dart` with version + status.

## Translation pipeline
Import → Parse → Normalize → Structure detection → Chapter segmentation → Chunking (token budget) → Glossary + instructions + bounded context → Provider adapter → Structural & terminology validation → Checkpoint save (SQLite transaction) → Review → Export.

Invariants (tested from V1-C on): no paragraph silently skipped; source immutable; chapter order kept; every chunk checkpointed with input hash + model + prompt + glossary version; resume never discards finished chunks; failed chunks retried individually; cache prevents duplicate calls; quality is measured by validators, not by the model's claim.

## Platform reality
- Android: WorkManager / foreground service where policy allows; process death → resume from checkpoint.
- iOS: BGTaskScheduler / BGContinuedProcessingTask where available; **no guaranteed long background run**. Resume + optional remote jobs is the reliability strategy.

## Security
BYOK keys in Keystore/Keychain; consent before cloud translation; hardened EPUB/DOCX unzip and XML parsing; no book text or keys in logs; minimal permissions.

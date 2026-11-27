# Harcama Takip

Flutter + Firebase (Firestore, Auth, Hosting) expense tracker. Android package `com.faydalab.harcama_takip`, also built for web. UI text is Turkish; English comes from `lib/core/l10n/translations_en.dart`.

## Layout
- `lib/domain` – entities and repository interfaces (pure Dart)
- `lib/data` – Firestore repositories, HTTP clients (`data/services`)
- `lib/application` – Riverpod providers and services
- `lib/presentation` – screens, widgets, GoRouter (`presentation/navigation/app_router.dart`)
- `lib/core` – constants (`AppConstants.appVersion` / `appBuildNumber`), l10n, theme, utils
- `firestore.rules` + `firestore-tests/rules.test.js` – security rules and their emulator tests
- `notification-worker/` – Cloudflare Worker that sends push notifications
- `test/helpers/fakes.dart` – `TestBackend` and fake repositories used by widget tests

## Commands
- Analyze: `flutter analyze` (must be clean)
- Tests: `flutter test` (all must pass)
- Rules tests (need JDK 21+; Git Bash):
  `export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"; export PATH="$JAVA_HOME/bin:$PATH"; cd firestore-tests && npm test`
- Web: `flutter build web --release` then `firebase deploy --only hosting`
- Rules: `firebase deploy --only firestore:rules,firestore:indexes`
- Android: `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`

## Conventions
- Every user-visible string uses `'Türkçe metin'.tr`; add the key to `translations_en.dart`. `translations_test` fails on missing **or unused** keys.
- New release: bump both `pubspec.yaml` `version:` and `AppConstants.appVersion` / `appBuildNumber`. Play never accepts a reused version code.
- External API calls (fuel prices, market rates, update check) must fail silently: keep last value, never show an error. Use `pollLatest` in `lib/core/utils/stream_utils.dart` for polling.
- Work directly on `main`; commit messages in English, imperative, conventional prefix (`feat:`, `fix:`…).
- For multi-line patch scripts, write them to a file and run it; bash heredocs with quotes/backslashes break.

## Do not
- Read `android/key.properties`, the keystore, or any service-account key.
- Deploy, publish, or submit to Play review without the user's explicit OK.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- When graphify-out/graph.json exists, run `graphify query "<question>"` before your first grep, search or source-file read for a codebase question, and put this rule in every subagent prompt that explores code. Read raw files only for lines the graph or an earlier read already located. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. When the answer is under a Markdown heading, `graphify section "<heading>"` prints that section's text, so the .md need not be opened. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
- A committed graphify-out/graph.json is rewritten whole on every build, so a large diff to it in a pull request is expected. Do not flag it as churn or suggest skipping the graph rebuild or its hooks.

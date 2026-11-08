# Repository Guidelines

## Project Structure & Module Organization
ShellLite is a Flutter SSH client for Android, iOS, and Web. Application code lives in `lib/`: `models/` defines data types, `providers/` holds Provider state stores, `services/` handles SSH, storage, and file transfer, and `screens/`, `widgets/`, and `theme/` implement the UI. Keep platform-specific socket and file-picker implementations in services. Tests live in `test/`, grouped by component. Runtime images and fonts are in `assets/`; store screenshots are in `docs/store_assets/`. Platform projects live in `android/`, `ios/`, and `web/`; automation lives in `.github/workflows/`, `scripts/`, and `systemd/`.

## Build, Test, and Development Commands
Use Flutter stable with a Dart SDK compatible with `^3.5.0`. Android builds require Java 17; iOS builds require macOS and Xcode.

- `flutter pub get`: install dependencies.
- `flutter run -d chrome`: run the web app locally.
- `flutter analyze`: run static analysis and lint checks.
- `dart format lib test`: format Dart source and tests.
- `flutter test`: run the full test suite.
- `flutter build web --base-href /`: build the web application.
- `flutter build apk --release` or `flutter build appbundle --release`: build Android artifacts.
- `flutter build ipa --release`: build the iOS artifact.

## Coding Style & Naming Conventions
Use standard Dart formatting with two-space indentation. Name files `snake_case.dart`, classes `UpperCamelCase`, and members `lowerCamelCase`. Follow `analysis_options.yaml`, which enables `flutter_lints` and prefers const constructors and declarations. Keep widgets focused and move connection or persistence logic into services and providers.

## Testing Guidelines
Use `flutter_test` for unit and widget tests. Name files `*_test.dart` under the relevant `test/` subdirectory. Run focused checks with commands such as `flutter test test/services/ssh_service_test.dart`. Test model, provider, and business-logic changes; run the suite before submitting code PRs. Routine documentation or styling edits do not require tests. No numeric coverage threshold is configured.

## Commit & Pull Request Guidelines
Follow the scoped Conventional Commits used in history: `feat(terminal): add shortcut` or `fix(test): remove unused import`. Release automation derives versions from commit types. Keep commits focused. PRs should describe the behavior change, link relevant issues, record validation, and include screenshots for visible UI changes. Push only when explicitly requested.

## Security & Configuration
Never commit SSH credentials, private keys, signing keystores, or service-account secrets. Web SSH requires a WebSocket bridge; native clients connect directly over TCP. Preserve this distinction when changing connection code.

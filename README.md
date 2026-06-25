# Career Client Agent

Flutter career opportunity application with a Python collection backend,
Riverpod/MVVM architecture, Hive offline caching, and GitHub Raw JSON sync.

## Remote JSON sync

The production GitHub Raw base URL is:

```text
https://raw.githubusercontent.com/Shoaib-Ayub/career-client-agent/main/backend_agent/data
```

Build an APK connected to the daily GitHub data:

```powershell
flutter build apk --release --dart-define=GITHUB_RAW_BASE_URL=https://raw.githubusercontent.com/Shoaib-Ayub/career-client-agent/main/backend_agent/data
```

For smaller per-architecture APKs:

```powershell
flutter build apk --release --split-per-abi --dart-define=GITHUB_RAW_BASE_URL=https://raw.githubusercontent.com/Shoaib-Ayub/career-client-agent/main/backend_agent/data
```

The app falls back in this order:

1. GitHub Raw JSON
2. Hive cache
3. Bundled `latest.json` assets

## Backend

Run the agents and publish stable JSON files:

```powershell
python -m backend_agent.main
python -m backend_agent.publish_latest
```

GitHub Actions runs the backend daily at 8:00 AM Pakistan time and commits the
updated cache snapshots, `latest.json` files, and `run_status.json`.

## Local API mode

```powershell
python -m backend_agent.main --serve
flutter run --dart-define=API_ENABLED=true --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## Verification

```powershell
flutter analyze
flutter test
python -m unittest discover -s backend_agent/tests -v
```

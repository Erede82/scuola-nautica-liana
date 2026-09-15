#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_VERSION="${APP_VERSION:-${1:-}}"
if [[ -z "$APP_VERSION" ]]; then
  echo "ERROR: APP_VERSION richiesta (YYYY.MM.DD.N)." >&2
  echo "Usage: APP_VERSION=2026.09.15.1 $0" >&2
  exit 1
fi

if ! [[ "$APP_VERSION" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]+$ ]]; then
  echo "ERROR: APP_VERSION formato invalido: $APP_VERSION (atteso YYYY.MM.DD.N)" >&2
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: working tree non pulito — commit o stash prima del build production." >&2
  exit 1
fi

APP_COMMIT_SHORT="$(git rev-parse --short HEAD)"
echo "Building production APP_VERSION=$APP_VERSION APP_COMMIT_SHORT=$APP_COMMIT_SHORT"

flutter build web \
  --release \
  --dart-define-from-file=env/prod.json \
  --dart-define=STARTUP_DIAGNOSTICS=false \
  --dart-define=APP_VERSION="$APP_VERSION" \
  --dart-define=APP_COMMIT_SHORT="$APP_COMMIT_SHORT"

VERSION_JSON="$ROOT/build/web/version.json"
if [[ ! -f "$VERSION_JSON" ]]; then
  echo "ERROR: $VERSION_JSON non generato da Flutter build." >&2
  exit 1
fi

BUILT_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
python3 - "$VERSION_JSON" "$APP_VERSION" "$APP_COMMIT_SHORT" "$BUILT_AT" <<'PY'
import json, sys
path, app_version, commit, built_at = sys.argv[1:5]
with open(path, encoding='utf-8') as f:
    data = json.load(f)
data['app_version'] = app_version
data['commit'] = commit
data['built_at'] = built_at
with open(path, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, sort_keys=True)
    f.write('\n')
if data.get('app_version') != app_version:
    raise SystemExit('merge version.json failed')
print('version.json merged OK')
print(json.dumps({k: data[k] for k in sorted(data)}, indent=2))
PY

LAST_RELEASE_FILE="$ROOT/.last_production_app_version"
if [[ -f "$LAST_RELEASE_FILE" ]]; then
  LAST="$(cat "$LAST_RELEASE_FILE")"
  if [[ "$LAST" == "$APP_VERSION" ]]; then
    echo "WARNING: APP_VERSION uguale all'ultima release registrata ($LAST)." >&2
  fi
fi
echo "$APP_VERSION" > "$LAST_RELEASE_FILE"

echo "Production web build OK: build/web (no deploy)"

#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
DEVICE="${FLUTTER_DEVICE:-iPhone 17 Pro Max}"
exec flutter run -d "$DEVICE" --dart-define-from-file=env/dev.json "$@"

#!/usr/bin/env bash
set -euo pipefail
app_version=$(python3 - <<'PY'
import re
from pathlib import Path
text = Path('pubspec.yaml').read_text()
match = re.search(r'^version: ([0-9]+\.[0-9]+\.[0-9]+)\+[0-9]+$', text, re.M)
if not match:
    raise SystemExit('Versione APK non valida')
print(match[1])
PY
)
apk_name="CataniaBus-${app_version}.apk"
release_dir=$(mktemp -d)
trap 'rm -rf "$release_dir"' EXIT
cp build/app/outputs/flutter-apk/app-release.apk "$release_dir/$apk_name"
(cd "$release_dir" && sha256sum "$apk_name" > "$apk_name.sha256")
release_tag="v$app_version"
release_title="CataniaBus $app_version"
release_args=(--latest)
if [[ "$GITHUB_EVENT_NAME" == "pull_request" ]]; then
  release_tag="preview-${app_version}-${GITHUB_RUN_NUMBER}"
  release_title="CataniaBus $app_version · anteprima PR #$PR_NUMBER"
  release_args=(--prerelease --latest=false)
fi
cat > "$release_dir/notes.md" <<'NOTES'
Scarica il file `.apk` per installare CataniaBus su Android: non serve estrarre alcuno ZIP.

Questa versione include navigazione Home/Bus/Metro, intestazioni coerenti e aggiornamento automatico dei dati AMTS. Le spiegazioni delle stime Metro si trovano nelle impostazioni. Le attese Metro sono stime da orario, non dati live.

La build personale usa una firma debug. Se Android segnala una firma diversa dalla versione già installata, occorre disinstallare quella precedente, perdendo dati locali e preferiti.
NOTES
if gh release view "$release_tag" --json assets,targetCommitish > "$release_dir/existing.json" 2>/dev/null; then
  if python3 - "$release_dir/existing.json" "$apk_name" <<'PY'
import json, sys
release = json.load(open(sys.argv[1]))
sys.exit(0 if any(a['name'] == sys.argv[2] for a in release['assets']) else 1)
PY
  then
    exit 0
  fi
  python3 - "$release_dir/existing.json" "$GITHUB_SHA" <<'PY'
import json, sys
if json.load(open(sys.argv[1]))['targetCommitish'] != sys.argv[2]:
    raise SystemExit('Release incompleta associata a un altro commit: aggiornare la versione')
PY
  gh release upload "$release_tag" "$release_dir/$apk_name" "$release_dir/$apk_name.sha256" --clobber
else
  gh release create "$release_tag" "$release_dir/$apk_name" "$release_dir/$apk_name.sha256" --target "$GITHUB_SHA" --title "$release_title" --notes-file "$release_dir/notes.md" "${release_args[@]}"
fi

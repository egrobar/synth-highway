#!/usr/bin/env bash
# Re-charts every built-in song that has Suno stems in sources/suno_stems/<id>/ with
# tools/importer/stem_chart.py (Easy / Normal / Hard from the stems, plus new lead and backing
# audio). Songs already charted from Suno stems are skipped unless --force; a Demucs chart is redone.
# Don't edit this file while a batch runs: bash reads a running script from disk as it goes.
# Each song runs through siege-pc's tools/heavy.sh: one heavy job at a time on this Mac; a refusal
# (exit 75: memory short or lock busy) waits a minute and tries again.
#
# Usage: tools/importer/chart_all_stems.sh [--force] [id ...]
# Log:   sources/stem_chart_log.tsv (id, result JSON or FAILED)
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PY="$ROOT/.venv-pipeline/bin/python"
HEAVY="$HOME/Desktop/siege-pc/tools/heavy.sh"
LOG="$ROOT/sources/stem_chart_log.tsv"
export PATH="/opt/homebrew/bin:$PATH"
force=0
ids=()
for arg in "$@"; do
  if [[ "$arg" == "--force" ]]; then force=1; else ids+=("$arg"); fi
done
if [[ ${#ids[@]} -eq 0 ]]; then
  for dir in "$ROOT"/sources/suno_stems/*/; do ids+=("$(basename "$dir")"); done
fi
done_count=0; skip_count=0; fail_count=0
for id in "${ids[@]}"; do
  chart="$ROOT/game/data/songs/$id.json"
  [[ -f "$chart" ]] || { echo "no chart for $id"; continue; }
  # A drums stem, MP3 or WAV (older Suno zips hold WAVs).
  [[ -n "$(find "$ROOT/sources/suno_stems/$id" -maxdepth 1 -name '*Drums*' 2>/dev/null)" ]] || { echo "no stems yet for $id"; continue; }
  # Already charted from Suno stems: skip. A Demucs chart (chart_all_demucs.sh) is redone from
  # the Suno stems once they arrive.
  if [[ $force -eq 0 ]] && grep -q '"chart_version": 2' "$chart" && ! grep -q '"stem_source": "demucs"' "$chart"; then
    skip_count=$((skip_count + 1)); continue
  fi
  echo "== $id"
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    "$HEAVY" --max-gb 6 --timeout 900 --name "synth-stemchart" -- "$PY" -W ignore "$ROOT/tools/importer/stem_chart.py" "$id" > "/tmp/synth-stemchart-$id.log" 2>&1
    status=$?
    [[ $status -ne 75 ]] && break
    echo "   memory short or lock busy; waiting a minute (attempt $attempt)"
    sleep 60
  done
  result="$(grep '^RESULT ' "/tmp/synth-stemchart-$id.log" | sed 's/^RESULT //')"
  if [[ -n "$result" ]]; then
    done_count=$((done_count + 1))
    echo "   $result"
    printf '%s\t%s\n' "$id" "$result" >> "$LOG"
  else
    fail_count=$((fail_count + 1))
    echo "   FAILED (exit $status):"; grep -E 'Error|Traceback|SystemExit' "/tmp/synth-stemchart-$id.log" | tail -3 | sed 's/^/   /'
    printf '%s\tFAILED\n' "$id" >> "$LOG"
  fi
done
echo "STEM CHARTS FINISHED: $done_count charted, $skip_count already done, $fail_count failed"

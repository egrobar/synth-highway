#!/usr/bin/env bash
# Charts the station songs that have no Suno stems from Demucs stems instead: for each, separates
# the original mix (tools/importer/demucs_stems.py -> sources/demucs_stems/<id>/) and charts it
# (tools/importer/stem_chart.py --demucs). Songs with Suno stems are left to chart_all_stems.sh,
# and songs already charted from stems of either kind are skipped unless named or --force.
# Both steps go through siege-pc's tools/heavy.sh (one heavy job at a time on this Mac); a
# refusal (exit 75) waits a minute and tries again. Ids named at the end of the list
# (LAST="id ...") go last, so songs whose Suno stems may still arrive are tried after the rest.
#
# Usage: tools/importer/chart_all_demucs.sh [--force] [id ...]
# Log:   sources/stem_chart_log.tsv (id, result JSON or FAILED), lines tagged "demucs"
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
  last=" ${LAST:-} "
  while IFS=$'\t' read -r id _; do
    [[ -n "$id" && "$last" != *" $id "* ]] && ids+=("$id")
  done < "$ROOT/sources/suno_titles.tsv"
  for id in ${LAST:-}; do ids+=("$id"); done
fi

heavy() {  # heavy <name> <command...>: retries while heavy.sh refuses
  local name="$1"; shift
  for attempt in $(seq 1 30); do
    "$HEAVY" --max-gb 6 --timeout 1500 --name "$name" -- "$@"
    local status=$?
    [[ $status -ne 75 ]] && return $status
    sleep 60
  done
  return 75
}

done_count=0; skip_count=0; fail_count=0
for id in "${ids[@]}"; do
  chart="$ROOT/game/data/songs/$id.json"
  [[ -f "$chart" ]] || { echo "no chart for $id"; continue; }
  if [[ -n "$(find "$ROOT/sources/suno_stems/$id" -maxdepth 1 -name '*Drums*' 2>/dev/null)" ]]; then
    skip_count=$((skip_count + 1)); continue  # Suno stems: chart_all_stems.sh's job
  fi
  if [[ $force -eq 0 ]] && grep -q '"chart_version": 2' "$chart"; then skip_count=$((skip_count + 1)); continue; fi
  echo "== $id"
  log="/tmp/synth-demucs-$id.log"
  heavy synth-demucs "$PY" -W ignore "$ROOT/tools/importer/demucs_stems.py" "$id" > "$log" 2>&1
  heavy synth-stemchart "$PY" -W ignore "$ROOT/tools/importer/stem_chart.py" "$id" --demucs >> "$log" 2>&1
  result="$(grep '^RESULT ' "$log" | sed 's/^RESULT //')"
  if [[ -n "$result" ]]; then
    done_count=$((done_count + 1))
    echo "   $result"
    printf '%s\tdemucs %s\n' "$id" "$result" >> "$LOG"
  else
    fail_count=$((fail_count + 1))
    echo "   FAILED:"; grep -E 'Error|Traceback|SystemExit' "$log" | tail -3 | sed 's/^/   /'
    printf '%s\tdemucs FAILED\n' "$id" >> "$LOG"
  fi
done
echo "DEMUCS CHARTS FINISHED: $done_count charted, $skip_count skipped, $fail_count failed"

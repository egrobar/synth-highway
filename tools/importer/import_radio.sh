#!/usr/bin/env bash
# Imports the space game's radio stations as built-in Synth Highway songs, one song at a time.
#
# Reads tools/importer/radio_manifest.tsv (station -> region), finds each station's songs in
# space-mmo/assets/radio/<station>/*.ogg (top level only: banter/ is DJ chatter), and runs
# import_song.py --builtin on each: stems to game/assets/songs/<id>/*.ogg, chart to
# game/data/songs/<id>.json, tagged with its station.
#
# Resumable: a song whose chart already exists is skipped, so it is safe to stop and rerun.
# Every import goes through siege-pc's tools/heavy.sh when it exists: one heavy job at a time on
# this Mac (24 GB, Docker holds 16), and it refuses to start when memory is short; this script then
# waits a minute and tries the same song again.
#
# Usage: tools/importer/import_radio.sh [station-folder ...]   (no arguments: every station)
# Env:   RADIO=/path/to/space-mmo/assets/radio
#        REIMPORT="id id ..."  import these songs again even though their charts exist
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RADIO="${RADIO:-$HOME/Desktop/space-mmo/assets/radio}"
PY="$ROOT/.venv-pipeline/bin/python"
HEAVY="$HOME/Desktop/siege-pc/tools/heavy.sh"
export PATH="/opt/homebrew/bin:$PATH"

MANIFEST="$ROOT/tools/importer/radio_manifest.tsv"
# Plain lookups: macOS ships bash 3.2, which has no associative arrays.
region_for() { awk -F'\t' -v k="$1" '$1 == k { print $2 }' "$MANIFEST"; }
override_for() { awk -F'\t' -v k="=$1" '$1 == k { print $2 }' "$MANIFEST"; }
title_override_for() { awk -F'\t' -v k="=$1" '$1 == k { print $3 }' "$MANIFEST"; }
reimport=" ${REIMPORT:-} "

stations=("$@")
if [[ ${#stations[@]} -eq 0 ]]; then
  while IFS= read -r line; do stations+=("$line"); done < <(awk -F'\t' '$1 !~ /^#/ && $1 !~ /^=/ && NF >= 2 { print $1 }' "$MANIFEST")
fi

done_count=0; skip_count=0; fail_count=0
for station in "${stations[@]}"; do
  region="$(region_for "$station")"
  [[ -z "$region" ]] && { echo "unknown station: $station"; continue; }
  # Station names display capitalised ("redline" -> "Redline").
  display="$(echo "${station:0:1}" | tr '[:lower:]' '[:upper:]')${station:1}"
  for file in "$RADIO/$station"/*.ogg; do
    [[ -f "$file" ]] || continue
    title="$(basename "$file" .ogg)"
    [[ "$title" == *_* ]] && title="$("$PY" -c "import sys; print(sys.argv[1].replace('_', ' ').title())" "$title")"
    renamed="$(title_override_for "$(basename "$file" .ogg)")"
    [[ -n "$renamed" ]] && title="$renamed"
    id="$("$PY" -c "import re,sys; print(re.sub(r'[^a-z0-9]+', '_', sys.argv[1].lower()).strip('_')[:40])" "$title")"
    song_region="$(override_for "$(basename "$file" .ogg)")"
    song_region="${song_region:-$region}"
    if [[ -f "$ROOT/game/data/songs/$id.json" && "$reimport" != *" $id "* ]]; then skip_count=$((skip_count + 1)); continue; fi
    echo "== $display / $title -> $song_region ($id)"
    for attempt in 1 2 3 4 5 6 7 8 9 10; do
      cmd=("$PY" -W ignore "$ROOT/tools/importer/import_song.py" "$file" - --builtin "$id" --theme "$song_region" --title "$title" --station "$display")
      if [[ -x "$HEAVY" ]]; then
        "$HEAVY" --max-gb 6 --timeout 900 --name "synth-radio" -- "${cmd[@]}" > "/tmp/synth-radio-$id.log" 2>&1
      else
        "${cmd[@]}" > "/tmp/synth-radio-$id.log" 2>&1
      fi
      status=$?
      [[ $status -ne 75 ]] && break
      echo "   memory short or lock busy; waiting a minute (attempt $attempt)"
      sleep 60
    done
    if grep -q '^DONE' "/tmp/synth-radio-$id.log"; then
      done_count=$((done_count + 1))
      grep -E 'PROGRESS 1.000|peak' "/tmp/synth-radio-$id.log" | sed 's/^/   /' | tail -2
    else
      fail_count=$((fail_count + 1))
      echo "   FAILED (exit $status):"; grep -E '^ERROR|Error|Segmentation' "/tmp/synth-radio-$id.log" | tail -3 | sed 's/^/   /'
    fi
  done
done
echo "RADIO IMPORT FINISHED: $done_count imported, $skip_count already there, $fail_count failed"

#!/usr/bin/env bash
# Rebuilds every generated game asset from source.
#
#   regions  tools/themes/<id>/props.py     Blender -> game/assets/themes/<id>/models/*.glb
#            tools/themes/<id>/textures.py  GIMP    -> game/assets/themes/<id>/textures/
#            tools/themes/<id>/ambience.scd SC      -> game/assets/themes/<id>/audio/ambience.wav
#   songs    tools/song/songs/<id>.py       chart   -> game/data/songs/<id>.json
#                                           SC      -> game/assets/songs/<id>/{backing,lead}.wav
#   shared   sound effects, the game logo, then Godot import and the rules tests
#
# Usage: tools/build_assets.sh [region-or-song-id ...]   (no arguments rebuilds everything)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export PATH="/opt/homebrew/bin:$PATH"
ONLY=("$@")

wanted() {
  [[ ${#ONLY[@]} -eq 0 ]] && return 0
  local id
  for id in "${ONLY[@]}"; do [[ "$id" == "$1" ]] && return 0; done
  return 1
}

gimp_run() {
  SYNTH_ROOT="$ROOT" gimp -i --quit --batch-interpreter=python-fu-eval -b "exec(open('$1').read())" 2>&1 \
    | grep -E "WROTE|DONE|Error|Traceback|line [0-9]+" || true
}

for dir in tools/themes/*/; do
  id="$(basename "$dir")"
  wanted "$id" || continue
  echo "== region $id"
  out="game/assets/themes/$id"
  mkdir -p "$out/models" "$out/textures" "$out/audio"
  [[ -f "$dir/props.py" ]] && blender --background --python "$dir/props.py" -- "$out/models" 2>&1 | grep -E "EXPORTED|Error|Traceback"
  [[ -f "$dir/textures.py" ]] && gimp_run "$dir/textures.py"
  if [[ -f "$dir/ambience.scd" ]]; then
    sclang tools/song/render_fx.scd ambience "$ROOT/$dir/ambience.scd" "$ROOT/$out/audio/ambience_raw.wav" 2>&1 | grep -E "RENDERED|ERROR" || true
    python3 tools/song/make_loop.py "$out/audio/ambience_raw.wav" "$out/audio/ambience.wav" 3 && rm "$out/audio/ambience_raw.wav"
  fi
done

for script in tools/song/songs/*.py; do
  id="$(basename "$script" .py)"
  wanted "$id" || continue
  echo "== song $id"
  python3 "$script"
  sclang tools/song/render_score.scd "$ROOT/tools/song/build/$id.scd" "$ROOT/game/assets/songs/$id" "$ROOT/tools/song/synths" 2>&1 \
    | grep -E "RENDERED|ERROR|unknown" || true
done

if [[ ${#ONLY[@]} -eq 0 ]]; then
  echo "== shared"
  sclang tools/song/render_fx.scd sfx "$ROOT/game/assets/audio" 2>&1 | grep -E "RENDERED|ERROR" || true
  gimp_run tools/gimp/ui_art.py
fi

echo "== Godot import and tests"
chmod +x tools/godot.sh
# An asset read mid-write is cached as invalid and never retried; drop those so they reimport.
grep -l -r --include='*.import' '^valid=false' game/assets 2>/dev/null | xargs rm -f
tools/godot.sh --headless --import >/dev/null 2>&1 || true
tools/godot.sh --headless -s res://tests/test_judge.gd 2>&1 | tail -1

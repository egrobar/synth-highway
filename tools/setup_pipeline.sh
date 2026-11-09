#!/usr/bin/env bash
# Builds the Python environment the in-game song importer runs: Demucs (stem
# separation), Basic Pitch (note transcription), librosa (tempo, key, pitch),
# pretty_midi and soundfile (MP3/WAV/FLAC reading without ffmpeg).
#
# Lives in .venv-pipeline/ at the repo root, which is where the game looks for it.
# Lyrics (faster-whisper) are left out for now: the game does not show them yet.
# Usage: tools/setup_pipeline.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export PATH="/opt/homebrew/bin:$PATH"

uv venv --python 3.11 .venv-pipeline
export VIRTUAL_ENV="$ROOT/.venv-pipeline"
uv pip install "torch==2.5.1" "torchaudio==2.5.1"
uv pip install "basic-pitch[onnx]>=0.4.0" "pretty_midi>=0.2.10" "librosa>=0.10" soundfile numpy
# Demucs 4.0.1 pins an old torchaudio it does not actually need, so install it
# without dependencies and add the ones it uses.
uv pip install --no-deps "demucs==4.0.1"
uv pip install dora-search einops julius lameenc openunmix pyyaml tqdm
# resampy (pulled in by librosa) still imports pkg_resources, which setuptools 81 removed.
uv pip install "setuptools<81"
.venv-pipeline/bin/python -c "import demucs, basic_pitch, librosa, pretty_midi, soundfile, torch; print('pipeline ready, torch', torch.__version__)"

"""Makes the web copy of the game that WASD Engine releases: build/web_project/.

WASD Engine takes a release of at most 512 MB zipped (found 2026-11-12), and the full game's web
build is ~940 MB, nearly all of it song audio: two stereo Ogg Vorbis stems a song at ~200 kbps
(import_song.write_stem's compression 0.3), and the authored songs' stems as WAV. This copies
game/ to build/web_project/ with every song stem re-encoded as Ogg Vorbis at compression LEVEL
(~92 kbps a stem; the authored songs' WAVs too, with their charts pointed at the .ogg), which brings
the web build to ~470 MB. game/ is untouched: the desktop game keeps its full-quality audio.

A re-run copies what changed in game/ and re-encodes only the stems whose source is newer than
their web copy; the copy's own .godot import cache and .wasdengine folder are kept. Release from
build/web_project/ every time, never from game/ (game/ is too big to release).

Usage: .venv-pipeline/bin/python tools/web/make_web_project.py
Then:  WASD Engine's wasd_release_game with project = <repo>/build/web_project
"""
from __future__ import annotations

import pathlib
import shutil
import subprocess
from concurrent.futures import ProcessPoolExecutor

import soundfile as sf

ROOT = pathlib.Path(__file__).resolve().parents[2]
GAME = ROOT / "game"
OUT = ROOT / "build/web_project"
# libsndfile's Vorbis compression level: 0.3 (the game's) is about quality 7, 0.75 about quality 2.5.
LEVEL = 0.75
STEMS = ("lead", "backing")
WORKERS = 3  # this Mac runs one heavy job at a time; three encoders stay well under a GB


def sync() -> None:
    """game/ -> build/web_project/, except the song stems (encoded below) and their .import files
    (the copy's own Godot writes those: a WAV song's stem is an .ogg here, with no source to copy)."""
    OUT.mkdir(parents=True, exist_ok=True)
    excludes = ["/.godot/", "/.wasdengine/", "/assets/songs/*/*.ogg", "/assets/songs/*/*.wav",
                "/assets/songs/*/*.import", "*.part"]
    args = ["rsync", "-a", "--delete"]
    for pattern in excludes:
        args += ["--exclude", pattern]
    subprocess.run([*args, f"{GAME}/", f"{OUT}/"], check=True)
    # rsync never deletes excluded files, so a song removed from game/ would keep its stems here.
    keep = {p.name for p in (GAME / "assets/songs").iterdir() if p.is_dir()}
    for song in (OUT / "assets/songs").iterdir():
        if song.is_dir() and song.name not in keep:
            shutil.rmtree(song)


def encode(src: pathlib.Path, dst: pathlib.Path) -> str:
    audio, rate = sf.read(str(src), dtype="float32", always_2d=True)
    dst.parent.mkdir(parents=True, exist_ok=True)
    part = dst.with_name(dst.name + ".part")  # Godot doesn't import a .part, if a run dies midway
    with sf.SoundFile(str(part), "w", rate, audio.shape[1], format="OGG", subtype="VORBIS",
                      compression_level=LEVEL) as f:
        # Small blocks: libsndfile's Vorbis encoder crashed on one big write (import_song.write_stem).
        for i in range(0, len(audio), 65536):
            f.write(audio[i:i + 65536])
    part.replace(dst)
    return f"{dst.parent.name}/{dst.name}"


def stale_stems() -> list[tuple[pathlib.Path, pathlib.Path]]:
    jobs = []
    for song in sorted(p for p in (GAME / "assets/songs").iterdir() if p.is_dir()):
        for stem in STEMS:
            src = next((song / f"{stem}{ext}" for ext in (".ogg", ".wav") if (song / f"{stem}{ext}").exists()), None)
            if src is None:
                continue
            dst = OUT / "assets/songs" / song.name / f"{stem}.ogg"
            if not dst.exists() or dst.stat().st_mtime < src.stat().st_mtime:
                jobs.append((src, dst))
    return jobs


def point_charts_at_ogg() -> int:
    """The authored songs' charts name lead.wav / backing.wav; here those stems are .ogg."""
    changed = 0
    for path in (OUT / "data/songs").glob("*.json"):
        text = path.read_text()
        new = text.replace('/lead.wav"', '/lead.ogg"').replace('/backing.wav"', '/backing.ogg"')
        if new != text:
            path.write_text(new)
            changed += 1
    return changed


def main() -> None:
    sync()
    jobs = stale_stems()
    print(f"encoding {len(jobs)} stems at compression {LEVEL}", flush=True)
    with ProcessPoolExecutor(WORKERS) as pool:
        for i, name in enumerate(pool.map(encode, *zip(*jobs)) if jobs else [], 1):
            print(f"  {i}/{len(jobs)} {name}", flush=True)
    charts = point_charts_at_ogg()
    size = sum(f.stat().st_size for f in (OUT / "assets/songs").rglob("*.ogg"))
    print(f"DONE: {len(jobs)} stems encoded, {charts} charts pointed at .ogg, "
          f"song audio {size / 1e6:.0f} MB in {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

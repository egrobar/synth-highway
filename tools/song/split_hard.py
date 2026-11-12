"""Hard for the authored songs: where a song's full melody chart rates as Hard, it becomes Hard.

The authored songs (tools/song/songs/, the classical pieces and the originals) are charted note for
note from their melody, so their charts already follow the music; what a playtest found (2026-11-11)
is that some of them are too hard for Normal ("some current normal songs might be hard"). This takes
a chart whose Normal rates at or above the Hard band (stem_chart.BANDS), keeps the full melody as
Hard with power chords (both hands) on its phrase starts, and thins Normal from it until it sits in
the Normal band and at least a level under Hard: passing notes go first, notes on the bar's strong
beats, long notes and melodic peaks stay. Lanes are untouched, so a note keeps its key at every
level. Songs whose full chart is a Normal stay Easy and Normal only.

songlib.write_chart calls add_hard() when a song is rebuilt; run this file to apply it to the
charts already written:
    .venv-pipeline/bin/python tools/song/split_hard.py [--force] [id ...]
(--force recomputes a song that already has Hard from its Hard chart.)
"""
from __future__ import annotations

import json
import pathlib
import sys

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/importer"))
sys.path.insert(0, str(ROOT / "tools/song"))
import stem_chart  # noqa: E402

# Phrase starts get a power chord on Hard; section starts also on Normal.
PHRASE_BARS = 4
HIT_SPACING = 1.5  # seconds between power chords, at least
NORMAL_CEILING = stem_chart.BANDS["normal"][1] - 0.5
HARD_FLOOR = stem_chart.BANDS["hard"][0]


def _grid(chart: dict, until: float) -> tuple[np.ndarray, np.ndarray]:
    beat = 60.0 / float(chart["bpm"])
    per_bar = int(chart.get("beats_per_bar", 4))
    offset = float(chart.get("beat_offset", 0.0))
    beats = offset + beat * np.arange(0, int(until / beat) + per_bar + 1)
    return beats, beats[::per_bar]


def _salience(notes: list[dict], beats: np.ndarray, downbeats: np.ndarray, beat: float) -> None:
    """sal on each note: its place in the bar, its length, and whether it is a melodic peak."""
    for i, n in enumerate(notes):
        metric = stem_chart.metric_weight(n["t"], beats, downbeats)
        length = min(float(n.get("d", 0.0)) / beat, 2.0) / 2.0
        before = notes[i - 1]["p"] if i > 0 else n["p"]
        after = notes[i + 1]["p"] if i + 1 < len(notes) else n["p"]
        peak = 1.0 if n["p"] > max(before, after) or n["p"] < min(before, after) else 0.0
        n["sal"] = 0.55 * metric + 0.3 * length + 0.15 * peak


def _hits(chart: dict, notes: list[dict], downbeats: np.ndarray, sections_only: bool) -> list[tuple[float, float]]:
    """(time, strength) of the notes that open a phrase (every PHRASE_BARS bars) or a section."""
    starts = [float(s["t"]) for s in chart.get("sections", [])]
    found: list[tuple[float, float]] = []
    for bar, t in enumerate(downbeats):
        section = any(abs(t - s) < 0.05 for s in starts)
        if sections_only and not section:
            continue
        if not section and bar % PHRASE_BARS:
            continue
        on = [n for n in notes if abs(n["t"] - t) < 0.04]
        if on and all(abs(on[0]["t"] - f) >= HIT_SPACING for f, _ in found):
            found.append((on[0]["t"], 2.0 if section else 1.0))
    return found


def add_hard(chart: dict, force: bool = False) -> dict:
    """The chart with Hard added and Normal thinned, when its full chart rates as Hard."""
    levels = chart.get("difficulties", {})
    if levels.get("hard") and not force:
        return chart
    full = [dict(n) for n in (levels.get("hard") or levels.get("normal") or [])]
    for n in full:
        n.pop("pw", None)
    full = [n for n in full if not n.get("chord_of")]
    # A forced rerun starts from Hard: drop the second note of each power chord it added.
    if levels.get("hard"):
        seen: set[float] = set()
        single = []
        for n, raw in zip(full, levels["hard"]):
            if raw.get("pw") and round(n["t"], 3) in seen:
                continue
            seen.add(round(n["t"], 3))
            single.append(n)
        full = single
    if len(full) < 16 or stem_chart.level_of(full) < HARD_FLOOR:
        return chart
    full.sort(key=lambda n: (n["t"], n["l"]))
    beat = 60.0 / float(chart["bpm"])
    beats, downbeats = _grid(chart, full[-1]["t"] + 1.0)
    _salience(full, beats, downbeats, beat)
    phrase_hits = _hits(chart, full, downbeats, sections_only=False)
    section_hits = _hits(chart, full, downbeats, sections_only=True)
    for n in full:
        n["keep"] = any(abs(n["t"] - t) < 0.04 for t, _ in section_hits)
    hard = stem_chart.with_power_chords(full, phrase_hits, 1.0)
    normal = stem_chart.thin_to(full, NORMAL_CEILING, 0.0)
    if stem_chart.level_of(hard) - stem_chart.level_of(normal) < 1.0:
        normal = stem_chart.thin_to(normal, stem_chart.level_of(hard) - 1.2, 0.0)
    normal = stem_chart.with_power_chords(normal, section_hits, 0.5)
    easy = [dict(n) for n in levels.get("easy", [])]
    if len(easy) > 16 and stem_chart.level_of(easy) > stem_chart.BANDS["easy"][1]:
        # An Easy over its band (Greensleeves' 3.9) loses its weakest notes the same way.
        _salience(easy, beats, downbeats, beat)
        for n in easy:
            n["keep"] = any(abs(n["t"] - t) < 0.04 for t, _ in section_hits)
        easy = stem_chart.thin_to(easy, stem_chart.BANDS["easy"][1], 0.0)
    out = dict(chart)
    out["difficulties"] = {**levels, "easy": _plain(easy), "normal": _plain(normal), "hard": _plain(hard)}
    out["notes"] = out["difficulties"]["normal"]
    return out


def _plain(notes: list[dict]) -> list[dict]:
    keys = ("t", "d", "p", "l", "s", "pw")
    return [{k: n[k] for k in keys if k in n and (k in ("t", "d", "p", "l") or n[k])} for n in notes]


def main(argv: list[str]) -> None:
    force = "--force" in argv
    ids = [a for a in argv if not a.startswith("--")]
    suno = set()
    titles = ROOT / "sources/suno_titles.tsv"
    if titles.exists():
        suno = {line.split("\t")[0] for line in titles.read_text().splitlines() if line.strip()}
    paths = [ROOT / f"game/data/songs/{i}.json" for i in ids] if ids else sorted((ROOT / "game/data/songs").glob("*.json"))
    for path in paths:
        if not ids and path.stem in suno:
            continue  # the station songs get Hard from their stems (tools/importer/stem_chart.py)
        chart = json.loads(path.read_text())
        before = {k: round(stem_chart.level_of(v), 1) for k, v in chart.get("difficulties", {}).items() if v}
        after_chart = add_hard(chart, force)
        if after_chart is chart:
            print(f"{path.stem}: unchanged {before}")
            continue
        after = {k: round(stem_chart.level_of(v), 1) for k, v in after_chart["difficulties"].items() if v}
        counts = {k: len(v) for k, v in after_chart["difficulties"].items()}
        path.write_text(json.dumps(after_chart, indent=1))
        print(f"{path.stem}: {before} -> {after} notes {counts}")


if __name__ == "__main__":
    main(sys.argv[1:])

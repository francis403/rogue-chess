#!/usr/bin/env python3
"""Measures the generated sounds (we can't listen in CI, so we measure).

    python3 -I tools/audio/check.py

Per file: duration, peak (dBFS), short-term loudness (loudest 50 ms RMS, dBFS),
DC offset, first/last sample level (clicks), spectral centroid (Hz, energy
weighted, Hann-windowed FFT), presence (share of the attack's energy, first
100 ms, in 1-4 kHz, dB: what survives on laptop speakers) and, for music, the loop-seam jump compared to the
track's own 99th-percentile sample step. Also checks that every id and variant in
config/ux.json has its file. Exits 1 if any check fails.

    python3 -I tools/audio/check.py --compare DIR   # also print another sfx folder's
                                                    # centroid/presence (before/after)
"""
import cmath
import json
import math
import os
import re
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DIRS = [("sfx", os.path.join(ROOT, "assets", "audio", "sfx")), ("music", os.path.join(ROOT, "assets", "audio", "music"))]

MAX_PEAK_DB = -0.95          # -1 dBFS plus quantisation slack
MAX_DC = 0.002
MAX_EDGE = 0.01              # first/last sample of a one-shot
MAX_CENTROID_HZ = 3000.0     # above this a sound reads as shrill
MAX_SFX_SECONDS = 1.5
MAX_STINGER_SECONDS = 4.0
MAX_MUSIC_SECONDS = 150.5     # long sectioned loops (was 40.5 for the iteration-1 vamps)
MAX_TOTAL_MB = 20.0
SFX_LOUDNESS_DB = -16.0       # generate.py renders every one-shot to this short-term loudness
LOUDNESS_TOLERANCE_DB = 0.6   # (peak capping may leave a very spiky sound slightly under)
STINGERS = {"victory", "defeat", "run_victory", "run_defeat", "unlock_fanfare"}
# Dark sounds that carry information and must still read on laptop speakers (roll-off
# below ~250 Hz): at least this much of their attack's energy (first 100 ms) sits in
# 1-4 kHz. Impacts (iteration 2), plus the refusal/cancel cues and "your turn"
# (iteration 3). Left out on purpose (see README): turn_opponent (a deliberately
# background tap, always with the banner and the opponent's own move sounds) and the
# stingers (musical phrases with their melody at 330-880 Hz, always with a full screen).
LAPTOP = {"capture", "explosion", "check", "piece_land_heavy", "ui_error", "ui_cancel", "turn_player"}
MIN_PRESENCE_DB = -14.5      # iteration 1 had -19.6 (capture) to -25.9 (check); ui_error was -33.7
CONFIG = os.path.join(ROOT, "config", "ux.json")


def read(path):
    with wave.open(path, "rb") as f:
        rate, ch, n = f.getframerate(), f.getnchannels(), f.getnframes()
        raw = f.readframes(n)
    ints = memoryview(raw).cast("h")
    chans = [[ints[i] / 32768.0 for i in range(c, len(ints), ch)] for c in range(ch)]
    return rate, chans


def fft(x):
    n = len(x)
    if n == 1:
        return x
    even, odd = fft(x[0::2]), fft(x[1::2])
    tw = [cmath.exp(-2j * math.pi * k / n) * odd[k] for k in range(n // 2)]
    return [even[k] + tw[k] for k in range(n // 2)] + [even[k] - tw[k] for k in range(n // 2)]


def centroid(x, rate, size=1024, max_frames=24):
    hann = [0.5 - 0.5 * math.cos(2 * math.pi * i / size) for i in range(size)]
    starts = list(range(0, max(1, len(x) - size), size // 2)) or [0]
    step = max(1, len(starts) // max_frames)
    num = den = 0.0
    for s in starts[::step]:
        seg = (x[s:s + size] + [0.0] * size)[:size]
        spec = fft([complex(v * w) for v, w in zip(seg, hann)])
        for k in range(1, size // 2):
            p = abs(spec[k]) ** 2
            num += p * k * rate / size
            den += p
    return num / den if den else 0.0


def presence(x, rate, size=512, window=0.1):
    """Share of the attack's spectral energy (first `window` s) between 1 and 4 kHz, in dB
    (0 = all of it). The attack is what tells a laptop listener something happened."""
    hann = [0.5 - 0.5 * math.cos(2 * math.pi * i / size) for i in range(size)]
    starts = list(range(0, max(1, min(len(x), int(window * rate)) - size // 2), size // 4)) or [0]
    band = total = 0.0
    for s in starts:
        seg = (x[s:s + size] + [0.0] * size)[:size]
        spec = fft([complex(v * w) for v, w in zip(seg, hann)])
        for k in range(1, size // 2):
            p = abs(spec[k]) ** 2
            total += p
            if 1000.0 <= k * rate / size <= 4000.0:
                band += p
    return 10 * math.log10(max(band, 1e-12) / total) if total else -99.0


def base_id(name):
    """capture_2 -> capture (variant files share their id's limits)."""
    m = re.match(r"^(.*)_(\d+)$", name)
    return m.group(1) if m else name


def check_config():
    """Every configured id (and each of its variants) has a file."""
    with open(CONFIG) as f:
        audio = json.load(f)["audio"]
    missing = []
    for section, (_, folder) in (("sounds", DIRS[0]), ("music", DIRS[1])):
        for sound_id, spec in audio[section].items():
            names = [sound_id] + ["%s_%d" % (sound_id, k) for k in range(2, int(spec.get("variants", 1)) + 1)]
            missing += [n for n in names if not os.path.exists(os.path.join(folder, n + ".wav"))]
    return missing


def short_term(x, rate):
    w = int(0.05 * rate)
    best = 1e-9
    for s in range(0, max(1, len(x) - w + 1), w // 2):
        seg = x[s:s + w]
        best = max(best, math.sqrt(sum(v * v for v in seg) / len(seg)))
    return 20 * math.log10(best)


def main():
    failures = []
    compare = sys.argv[sys.argv.index("--compare") + 1] if "--compare" in sys.argv else None
    print("%-6s %-20s %6s %7s %7s %7s %7s %8s %6s %s" % ("kind", "id", "sec", "peak", "loud", "rms", "dc", "centroid",
                                                         "pres", "edges/seam"))
    total_bytes = 0
    for kind, folder in DIRS:
        for name in sorted(os.listdir(folder)):
            if not name.endswith(".wav"):
                continue
            path = os.path.join(folder, name)
            total_bytes += os.path.getsize(path)
            sound_id = base_id(name[:-4])
            rate, chans = read(path)
            mono = [sum(f) / len(f) for f in zip(*chans)]
            seconds = len(mono) / rate
            peak = 20 * math.log10(max(1e-9, max(abs(v) for c in chans for v in c)))
            rms = 20 * math.log10(max(1e-9, math.sqrt(sum(v * v for v in mono) / len(mono))))
            dc = max(abs(sum(c) / len(c)) for c in chans)
            cen = centroid(mono, rate)
            pres = presence(mono, rate)
            loud = short_term(mono, rate)
            problems = []
            if kind == "sfx" and sound_id in LAPTOP and pres < MIN_PRESENCE_DB:
                problems.append("thin on laptops")
            if kind == "sfx" and abs(loud - SFX_LOUDNESS_DB) > LOUDNESS_TOLERANCE_DB:
                problems.append("loudness")
            if peak > MAX_PEAK_DB:
                problems.append("peak")
            if dc > MAX_DC:
                problems.append("dc")
            if cen > MAX_CENTROID_HZ:
                problems.append("shrill")
            if kind == "music":
                seam = max(abs(c[0] - c[-1]) for c in chans)
                steps = sorted(abs(c[i + 1] - c[i]) for c in chans for i in range(len(c) - 1))
                typical = steps[int(len(steps) * 0.99)]
                edge = "seam %.4f (p99 step %.4f)" % (seam, typical)
                if seam > typical:
                    problems.append("seam")
                if seconds > MAX_MUSIC_SECONDS:
                    problems.append("too long")
            else:
                first, last = max(abs(c[0]) for c in chans), max(abs(c[-1]) for c in chans)
                edge = "first %.4f last %.4f" % (first, last)
                if first > MAX_EDGE or last > MAX_EDGE:
                    problems.append("click")
                limit = MAX_STINGER_SECONDS if sound_id in STINGERS else MAX_SFX_SECONDS
                if seconds > limit:
                    problems.append("too long")
            print("%-6s %-20s %6.2f %7.1f %7.1f %7.1f %7.4f %8.0f %6.1f %s %s" % (
                kind, name[:-4], seconds, peak, loud, rms, dc, cen, pres, edge,
                ("FAIL: " + ", ".join(problems)) if problems else ""))
            failures += [name[:-4]] if problems else []
    print("total size: %.2f MB" % (total_bytes / 1e6))
    if total_bytes / 1e6 > MAX_TOTAL_MB:
        failures.append("total size > %.0f MB" % MAX_TOTAL_MB)
    missing = check_config()
    if missing:
        print("configured but missing:", ", ".join(missing))
        failures += missing
    if compare:
        print("\ncompare (%s -> current):" % compare)
        for name in sorted(os.listdir(compare)):
            if name.endswith(".wav"):
                old = read(os.path.join(compare, name))
                new = read(os.path.join(DIRS[0][1], name))
                o, n = [[sum(f) / len(f) for f in zip(*c)] for c in (old[1], new[1])]
                print("  %-18s centroid %5.0f -> %5.0f Hz   presence %6.1f -> %6.1f dB   %4.2f -> %4.2f s" % (
                    name[:-4], centroid(o, old[0]), centroid(n, new[0]), presence(o, old[0]), presence(n, new[0]),
                    len(o) / old[0], len(n) / new[0]))
    if failures:
        print("FAILED:", ", ".join(failures))
        return 1
    print("all checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())

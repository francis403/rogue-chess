#!/usr/bin/env python3
"""RogueChess sound generator: synthesizes every sound effect and music loop.

Standard library only, fully deterministic (fixed seeds). Run from anywhere:

    python3 -I tools/audio/generate.py            # everything
    python3 -I tools/audio/generate.py capture    # only the named ids

Writes 16-bit 22.05 kHz mono WAVs into assets/audio/sfx/ (high-frequency
sounds in 3 variants: <id>.wav, <id>_2.wav, <id>_3.wav) and assets/audio/music/
(long seamless loops in sections). See tools/audio/README.md.

Mood: "club room at night" - wooden pieces on felt, soft brass chimes,
a late-night lounge. Everything sits in a warm register: no partial above
MAX_PARTIAL_HZ, gentle attacks except for impacts.
"""
import array
import math
import os
import random
import sys
import wave

SR = 22050
TAU = 2.0 * math.pi
MAX_PARTIAL_HZ = 5000.0      # keeps everything warm, nothing shrill
PEAK_CEILING_DB = -1.0
SFX_LOUDNESS_DB = -16.0      # short-term (50 ms) loudness every SFX is matched to
MUSIC_RMS_DB = -21.0         # music loops sit lower than effects

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "assets", "audio", "music")


# =============================================================================
# DSP helpers
# =============================================================================

def frames(sec):
    return max(1, int(round(sec * SR)))


def zeros(sec):
    return [0.0] * frames(sec)


def hz(midi):
    """MIDI note number -> frequency."""
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def db(value):
    return 10.0 ** (value / 20.0)


def add(dst, src, at=0.0, gain=1.0):
    """Mixes src into dst starting at `at` seconds (dst grows if needed)."""
    start = int(round(at * SR))
    end = start + len(src)
    if end > len(dst):
        dst.extend([0.0] * (end - len(dst)))
    for i, v in enumerate(src):
        dst[start + i] += v * gain
    return dst


def scale(x, gain):
    return [v * gain for v in x]


def mul(x, env):
    return [a * b for a, b in zip(x, env)]


def env_perc(dur, attack, decay):
    """Linear attack then exponential decay (decay = time constant, seconds)."""
    n, a = frames(dur), max(1, int(attack * SR))
    k = 1.0 / (decay * SR)
    return [i / a if i < a else math.exp(-(i - a) * k) for i in range(n)]


def env_swell(dur, peak=0.5, power=1.5):
    """Smooth rise to `peak` (fraction of dur) then smooth fall: for whooshes and slides."""
    n = frames(dur)
    out = []
    for i in range(n):
        p = i / n
        s = p / peak if p < peak else (1.0 - p) / (1.0 - peak)
        out.append(math.sin(0.5 * math.pi * s) ** power)
    return out


def fade(x, fade_in=0.002, fade_out=0.02):
    """Short raised-cosine fades at both ends so nothing clicks."""
    x = list(x)
    a, b = min(len(x), frames(fade_in)), min(len(x), frames(fade_out))
    for i in range(a):
        x[i] *= 0.5 - 0.5 * math.cos(math.pi * i / a)
    for i in range(b):
        x[-1 - i] *= 0.5 - 0.5 * math.cos(math.pi * i / b)
    return x


def noise(dur, seed):
    rng = random.Random(seed)
    return [rng.uniform(-1.0, 1.0) for _ in range(frames(dur))]


def partials(freq, dur, spec, attack=0.004):
    """Sum of decaying sines: spec = [(ratio, amplitude, decay_seconds)].
    Modal synthesis for wood knocks, bells and chimes. Partials above
    MAX_PARTIAL_HZ are dropped."""
    n = frames(dur)
    out = [0.0] * n
    a = max(1, int(attack * SR))
    for ratio, amp, decay in spec:
        f = freq * ratio
        if f >= MAX_PARTIAL_HZ:
            continue
        w, k = TAU * f / SR, 1.0 / (decay * SR)
        for i in range(n):
            out[i] += amp * math.sin(w * i) * math.exp(-i * k)
    for i in range(min(a, n)):
        out[i] *= i / a
    return out


def glide(f0, f1, dur, harmonics=((1, 1.0),)):
    """Tone whose pitch slides exponentially from f0 to f1."""
    n = frames(dur)
    out, phase = [], 0.0
    for i in range(n):
        f = f0 * (f1 / f0) ** (i / n)
        phase += TAU * f / SR
        out.append(sum(a * math.sin(h * phase) for h, a in harmonics))
    return out


def svf(x, freq, q=0.707, mode="lp"):
    """Zero-delay state-variable filter (lp / bp / hp). `freq` is Hz or a
    function of progress 0..1 (for sweeps). bp is normalised to unity peak."""
    k = 1.0 / q
    ic1 = ic2 = 0.0
    n = len(x)
    sweep = callable(freq)

    def coeffs(f):
        g = math.tan(math.pi * min(f, SR * 0.45) / SR)
        a1 = 1.0 / (1.0 + g * (g + k))
        return a1, g * a1, g * g * a1

    a1, a2, a3 = coeffs(freq(0.0) if sweep else freq)
    out = [0.0] * n
    for i, v in enumerate(x):
        if sweep and i % 16 == 0:
            a1, a2, a3 = coeffs(freq(i / n))
        v3 = v - ic2
        v1 = a1 * ic1 + a2 * v3
        v2 = ic2 + a2 * ic1 + a3 * v3
        ic1, ic2 = 2.0 * v1 - ic1, 2.0 * v2 - ic2
        if mode == "lp":
            out[i] = v2
        elif mode == "bp":
            out[i] = k * v1
        else:
            out[i] = v - k * v1 - v2
    return out


def lowpass(x, freq):
    return svf(x, freq, 0.707, "lp")


def highpass(x, freq):
    return svf(x, freq, 0.707, "hp")


def bandpass(x, freq, q=1.0):
    return svf(x, freq, q, "bp")


def soft_clip(x, drive=1.5):
    norm = math.tanh(drive)
    return [math.tanh(drive * v) / norm for v in x]


_COMBS = (557, 593, 641, 677, 709, 743)
_ALLPASSES = (277, 211)


def _freeverb(x, room, damp, spread):
    """Mono Schroeder/Freeverb-style reverb (combs with damping + allpasses)."""
    n = len(x)
    out = [0.0] * n
    for d in _COMBS:
        d += spread
        buf, idx, store = [0.0] * d, 0, 0.0
        for i in range(n):
            y = buf[idx]
            store = y * (1.0 - damp) + store * damp
            buf[idx] = x[i] + store * room
            idx = idx + 1 if idx + 1 < d else 0
            out[i] += y
    for d in _ALLPASSES:
        d += spread
        buf, idx = [0.0] * d, 0
        for i in range(n):
            b, v = buf[idx], out[i]
            out[i] = b - v
            buf[idx] = v + b * 0.5
            idx = idx + 1 if idx + 1 < d else 0
    return scale(out, 1.0 / len(_COMBS))


def reverb(x, wet=0.2, room=0.8, damp=0.45, tail=0.6):
    """Adds a small warm room to a mono sound (extends it by `tail` seconds)."""
    dry = list(x) + zeros(tail)
    wet_sig = _freeverb(lowpass(dry, 3500), room, damp, 0)
    return [d + wet * w for d, w in zip(dry, wet_sig)]


def short_term_peak(x, window=0.05):
    """Loudest 50 ms RMS window (a crude short-term loudness)."""
    w = frames(window)
    hop = max(1, w // 2)
    best = 1e-9
    for s in range(0, max(1, len(x) - w + 1), hop):
        seg = x[s:s + w]
        best = max(best, math.sqrt(sum(v * v for v in seg) / len(seg)))
    return best


def finish(x, loudness_db=SFX_LOUDNESS_DB, fade_in=0.002, fade_out=0.03):
    """Removes DC/rumble, trims silent tail, fades, matches loudness, caps the peak."""
    x = highpass(x, 35.0)
    floor = max(abs(v) for v in x) * db(-60)
    end = len(x)
    while end > frames(0.05) and abs(x[end - 1]) < floor:
        end -= 1
    x = fade(x[:end], fade_in, fade_out)
    gain = db(loudness_db) / short_term_peak(x)
    peak = max(abs(v) for v in x) * gain
    if peak > db(PEAK_CEILING_DB):
        gain *= db(PEAK_CEILING_DB) / peak
    return scale(x, gain)


def write_wav(path, channels):
    """channels: list of 1 (mono) or 2 (stereo) equal-length float lists."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = array.array("h")
    for frame in zip(*channels):
        for v in frame:
            data.append(int(round(max(-1.0, min(1.0, v)) * 32767)))
    if sys.byteorder == "big":
        data.byteswap()
    with wave.open(path, "wb") as f:
        f.setnchannels(len(channels))
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(data.tobytes())


# =============================================================================
# Instruments (shared voices)
# =============================================================================

def knock(freq, dur=0.25, decay=0.05, seed=1, click=0.35):
    """Wooden knock: a few inharmonic modes plus a short filtered noise tick."""
    spec = [(1.0, 1.0, decay), (2.57, 0.45, decay * 0.55), (4.1, 0.2, decay * 0.35), (6.3, 0.08, decay * 0.2)]
    x = partials(freq, dur, spec, attack=0.0008)
    tick = mul(bandpass(noise(0.015, seed), min(freq * 3.0, 3500), 0.9), env_perc(0.015, 0.0005, 0.003))
    return add(x, tick, 0.0, click)


def felt_thud(dur=0.12, seed=2, cutoff=350):
    """Soft low thump of something landing on felt."""
    return mul(lowpass(lowpass(noise(dur, seed), cutoff), cutoff), env_perc(dur, 0.002, dur * 0.25))


def bell(freq, dur=1.0, decay=0.6, bright=0.6, attack=0.006):
    """Soft brass chime: inharmonic partials, the upper ones dying quickly."""
    spec = [(1.0, 1.0, decay), (2.0, 0.35 * bright, decay * 0.6), (2.76, 0.22 * bright, decay * 0.45),
            (4.07, 0.1 * bright, decay * 0.25), (5.4, 0.05 * bright, decay * 0.15)]
    return partials(freq, dur, spec, attack)


def metal(freq, dur=0.9, decay=0.45):
    """Steel plate ring (shield): denser inharmonic partials than a bell."""
    spec = [(1.0, 1.0, decay), (1.47, 0.6, decay * 0.8), (2.32, 0.45, decay * 0.6),
            (3.11, 0.25, decay * 0.4), (4.16, 0.12, decay * 0.25)]
    return partials(freq, dur, spec, attack=0.001)


def rhodes(freq, dur, vel=0.7, decay=None, hold=None):
    """Electric-piano-like FM voice: 1:1 FM with a decaying index plus a soft tine.
    `hold` (seconds) releases the note early; the rest of `dur` is the ring-out."""
    n = frames(dur)
    decay = decay or (1.2 + 1.2 * (300.0 / max(freq, 60.0)) ** 0.5)
    w = TAU * freq / SR
    index0 = 0.4 + 1.4 * vel
    tine_on = freq * 7.0 < MAX_PARTIAL_HZ
    release_at = frames(hold) if hold else n
    release = frames(0.18)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        env = min(1.0, t / 0.005) * math.exp(-t / decay)
        if i > release_at:
            env *= max(0.0, 1.0 - (i - release_at) / release)
            if env == 0.0:
                break
        index = index0 * math.exp(-t / 0.3) + 0.12
        v = math.sin(w * i + index * math.sin(w * i))
        if tine_on:
            v += 0.1 * vel * math.sin(7.0 * w * i) * math.exp(-t / 0.04)
        out[i] = v * env * (0.35 + 0.65 * vel)
    return out


def upright(freq, dur, vel=0.7):
    """Round plucked bass: sine plus soft harmonics, a felt thump on the attack."""
    n = frames(dur)
    w = TAU * freq / SR
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        env = min(1.0, t / 0.008) * math.exp(-t / 0.7)
        bright = math.exp(-t / 0.12)
        out[i] = env * (math.sin(w * i) + (0.25 + 0.2 * bright) * math.sin(2 * w * i)
                        + 0.12 * bright * math.sin(3 * w * i))
    out = fade(out, 0.0, 0.08)
    add(out, felt_thud(0.05, int(freq), 250), 0.0, 0.25)
    return scale(out, 0.4 + 0.6 * vel)


def chord(midis, dur, vel=0.6, strum=0.012, hold=None, rng=None):
    """A Rhodes chord, lightly strummed bottom to top."""
    out = zeros(dur)
    for k, m in enumerate(midis):
        v = vel * (rng.uniform(0.9, 1.05) if rng else 1.0)
        add(out, rhodes(hz(m), dur - k * strum, v, hold=hold), k * strum, 1.0 / len(midis) ** 0.5)
    return out


def paper(dur, f0, f1, seed, q=1.2, peak=0.35):
    """Card/paper slide: band-passed noise with a moving centre, swelled."""
    sweep = lambda p: f0 * (f1 / f0) ** p
    return mul(bandpass(noise(dur, seed), sweep, q), env_swell(dur, peak))


def whoosh(dur, f0, f1, seed, peak=0.5, q=0.8):
    """Soft air movement: band-passed noise sweep under a smooth swell."""
    return lowpass(paper(dur, f0, f1, seed, q, peak), 2500)


def crackles(dur, per_second, seed, freq=1700, fade_to=1.0):
    """Sparse fire crackles: tiny filtered noise bursts at random times.
    Density falls linearly to `fade_to` x by the end."""
    rng = random.Random(seed)
    out = zeros(dur)
    t = 0.0
    while t < dur - 0.02:
        density = per_second * (1.0 + (fade_to - 1.0) * t / dur)
        t += rng.expovariate(max(density, 0.1))
        if t >= dur - 0.02:
            break
        burst = mul(bandpass(noise(0.012, rng.randrange(1 << 30)), freq * rng.uniform(0.7, 1.3), 1.5),
                    env_perc(0.012, 0.0005, 0.002))
        add(out, burst, t, rng.uniform(0.3, 1.0))
    return out


def breath(dur, f0, f1, seed, peak=0.3):
    """Low airy noise (fire body, exhale)."""
    sweep = lambda p: f0 * (f1 / f0) ** p
    return mul(lowpass(lowpass(noise(dur, seed), sweep), sweep), env_swell(dur, peak, 1.0))


def arpeggio(midis, gap, dur, decay=0.6, bright=0.5, gain_step=0.0):
    out = zeros(dur)
    for k, m in enumerate(midis):
        add(out, bell(hz(m), dur - k * gap, decay, bright), k * gap, 1.0 - k * gain_step)
    return out


def snap(freq=2000.0, seed=0, decay=0.006):
    """Presence layer for laptop speakers (which roll off below ~250 Hz): a short,
    dry wood snap in the 1-3 kHz band. A few fast modes plus a band-passed tick;
    it marks the attack without making the sound brighter overall."""
    x = partials(freq, 0.08, [(1.0, 1.0, decay), (1.48, 0.5, decay * 0.7), (2.1, 0.25, decay * 0.5)], attack=0.0005)
    tick = mul(bandpass(noise(0.02, seed), freq * 1.2, 1.2), env_perc(0.02, 0.0004, 0.004))
    return add(x, tick, 0.0, 0.8)


# Variants: high-frequency sounds are rendered 3 times (<id>.wav, <id>_2.wav, <id>_3.wav)
# and Sfx picks one at random, never the same twice in a row. A variant changes the seeds
# (noise grain, rattle timing) and nudges pitch/decay a little, so the sound stays the
# same object hit differently, never a different sound.
VARIANT_RATIO = (1.0, 0.95, 1.055)


def vr(v):
    return VARIANT_RATIO[v]


def vs(seed, v):
    return seed + 1000 * v


# =============================================================================
# UI
# =============================================================================

def ui_hover(v=0):
    return finish(knock(1400 * vr(v), 0.05, 0.008, seed=vs(11, v), click=0.15), fade_out=0.01)


def ui_click(v=0):
    x = knock(900 * vr(v), 0.1, 0.016 * (1.0, 1.1, 0.9)[v], seed=vs(12, v))
    return finish(x, fade_out=0.02)


def ui_confirm():
    x = bell(hz(72), 0.6, 0.3, 0.5)
    add(x, bell(hz(79), 0.53, 0.35, 0.5), 0.07, 0.8)
    return finish(reverb(x, 0.15, tail=0.3))


def ui_cancel():
    """A soft falling fourth (G4-D4). Presence: a quiet brass blip a twelfth up (D6-A5,
    the same falling fourth, ~60 ms decay) so it still reads on laptop speakers."""
    x = bell(hz(67), 0.4, 0.2, 0.3)
    add(x, bell(hz(62), 0.33, 0.25, 0.3), 0.07, 0.9)
    add(x, bell(hz(86), 0.25, 0.06, 0.4, attack=0.002), 0.0, 0.4)
    add(x, bell(hz(81), 0.25, 0.06, 0.4, attack=0.002), 0.07, 0.36)
    return finish(x)


def ui_error():
    x = knock(180, 0.35, 0.06, seed=13, click=0.2)
    add(x, knock(170, 0.24, 0.06, seed=14, click=0.2), 0.11)
    tone = mul([math.sin(TAU * 196 * i / SR) + math.sin(TAU * 207.6 * i / SR) for i in range(frames(0.3))],
               env_perc(0.3, 0.01, 0.08))
    add(x, tone, 0.0, 0.25)
    # Presence: a muted wood "tock" (1.1 kHz, low-passed, ~14 ms) on top of each knock,
    # so the refusal reads on laptop speakers; the dull double knock stays the message.
    add(x, lowpass(knock(1100, 0.08, 0.014, seed=113, click=0.3), 2400), 0.0, 0.8)
    add(x, lowpass(knock(1034, 0.08, 0.014, seed=114, click=0.3), 2400), 0.11, 0.68)
    return finish(x)


def ui_purchase():
    coin = lambda f: partials(f, 0.4, [(1, 1, 0.12), (2.4, 0.5, 0.07), (3.9, 0.25, 0.04)], 0.001)
    x = coin(1400)
    add(x, coin(1520), 0.07, 0.8)
    add(x, arpeggio([72, 76, 79], 0.03, 0.75, 0.45, 0.5), 0.13, 0.7)
    return finish(reverb(x, 0.18, tail=0.4))


def ui_toggle():
    x = knock(1100, 0.12, 0.01, seed=15)
    add(x, knock(800, 0.08, 0.012, seed=16), 0.035, 0.8)
    return finish(x, fade_out=0.02)


def ui_open():
    x = whoosh(0.3, 300, 1500, seed=17, peak=0.6)
    add(x, knock(220, 0.2, 0.04, seed=18, click=0.1), 0.0, 0.5)
    return finish(x)


def ui_close():
    x = whoosh(0.26, 1400, 300, seed=19, peak=0.4)
    add(x, knock(200, 0.12, 0.04, seed=20, click=0.1), 0.2, 0.6)
    return finish(x)


# =============================================================================
# Cards
# =============================================================================

def card_draw(v=0):
    dur, peak = ((0.22, 0.3), (0.2, 0.25), (0.24, 0.35))[v]
    return finish(lowpass(paper(dur, 1200 * vr(v), 2600 * vr(v), seed=vs(21, v), peak=peak), 4000))


def card_shuffle():
    rng = random.Random(22)
    x = scale(paper(0.6, 1600, 2400, seed=23, q=0.9, peak=0.5), 0.35)
    t = 0.02
    for _ in range(12):
        flick = mul(bandpass(noise(0.02, rng.randrange(1 << 30)), rng.uniform(1700, 2600), 1.3),
                    env_perc(0.02, 0.001, 0.006))
        add(x, flick, t, rng.uniform(0.5, 1.0))
        t += rng.uniform(0.035, 0.05)
    add(x, knock(650, 0.15, 0.02, seed=24, click=0.3), 0.64, 0.5)
    add(x, felt_thud(0.1, 25), 0.64, 0.4)
    return finish(x)


def card_play():
    x = paper(0.08, 900, 1600, seed=26, peak=0.6)
    add(x, felt_thud(0.15, 27, 900), 0.07, 0.9)
    add(x, knock(300, 0.15, 0.03, seed=28, click=0.1), 0.07, 0.3)
    return finish(x)


def card_discard():
    x = paper(0.18, 1800, 900, seed=29, peak=0.4)
    add(x, felt_thud(0.12, 30, 600), 0.15, 0.6)
    return finish(x)


def card_select():
    x = mul(bandpass(noise(0.03, 31), 2100, 1.2), env_perc(0.03, 0.002, 0.008))
    add(x, bell(hz(83), 0.2, 0.08, 0.2), 0.01, 0.35)
    return finish(x)


def card_hover(v=0):
    return finish(paper(0.07, 1500 * vr(v), 2000 * vr(v), seed=vs(32, v), q=0.9, peak=0.4), fade_out=0.01)


# =============================================================================
# Pieces
# =============================================================================

def piece_pickup(v=0):
    x = knock(900 * vr(v), 0.1, 0.012, seed=vs(41, v), click=0.2)
    add(x, scale(paper(0.05, 700 * vr(v), 1400 * vr(v), seed=vs(42, v), peak=0.2), 0.5), 0.01)
    return finish(x, fade_out=0.02)


def piece_move(v=0):
    rng = random.Random(vs(43, v))
    dur = (0.28, 0.26, 0.3)[v]
    x = lowpass(lowpass(noise(dur, vs(44, v)), 800 * vr(v)), 1100 * vr(v))
    rate = (23, 19, 27)[v]
    flutter = [1.0 + 0.25 * math.sin(TAU * rate * i / SR + rng.random()) for i in range(len(x))]
    return finish(mul(mul(x, flutter), env_swell(dur, (0.25, 0.3, 0.22)[v], 1.0)), fade_out=0.05)


def piece_land_light(v=0):
    x = knock(560 * vr(v), 0.25, 0.035 * (1.0, 1.1, 0.92)[v], seed=vs(45, v))
    add(x, felt_thud(0.08, vs(46, v), 400), 0.0, 0.5)
    return finish(x)


def piece_land_medium(v=0):
    x = knock(400 * vr(v), 0.3, 0.05 * (1.0, 1.1, 0.92)[v], seed=vs(47, v))
    add(x, felt_thud(0.1, vs(48, v), 350), 0.0, 0.7)
    return finish(x)


def piece_land_heavy(v=0):
    x = knock(280 * vr(v), 0.4, 0.07 * (1.0, 1.1, 0.92)[v], seed=vs(49, v))
    add(x, felt_thud(0.14, vs(50, v), 300), 0.0, 0.9)
    add(x, mul(glide(95 * vr(v), 70 * vr(v), 0.3), env_perc(0.3, 0.002, 0.08)), 0.0, 0.6)
    add(x, snap(1500 * vr(v), vs(150, v), 0.012), 0.0, 1.0)   # a hint of presence on laptops
    return finish(x)


def capture(v=0):
    """Wood on wood: a low knock, a felt thud, the taken piece rattling away, plus a
    dry 1.9 kHz snap on the attack so it still reads on laptop speakers."""
    x = knock(300 * vr(v), 0.4, 0.08, seed=vs(51, v))
    add(x, felt_thud(0.15, vs(52, v), 400), 0.0, 0.8)
    add(x, snap(1900 * vr(v), vs(151, v), 0.012), 0.0, 1.0)
    rng = random.Random(vs(53, v))
    t = 0.12
    for gain in (0.4, 0.27, 0.17, 0.1, 0.06):
        add(x, knock(rng.uniform(500, 620), 0.12, 0.02, seed=rng.randrange(1000), click=0.2), t, gain)
        t += rng.uniform(0.045, 0.075) * (1.0 - gain)
    return finish(reverb(x, 0.12, tail=0.2))


def shield_block():
    x = metal(620, 0.9, 0.42)
    add(x, knock(350, 0.2, 0.03, seed=54), 0.0, 0.6)
    return finish(reverb(lowpass(x, 3800), 0.2, tail=0.4))


def explosion():
    body = lowpass(lowpass(noise(1.3, 55), lambda p: 2400 * (0.06 ** p)), lambda p: 2400 * (0.06 ** p))
    x = mul(body, env_perc(1.3, 0.004, 0.32))
    add(x, mul(glide(110, 36, 0.8), env_perc(0.8, 0.003, 0.3)), 0.0, 0.9)
    rng = random.Random(56)
    for _ in range(5):
        add(x, knock(rng.uniform(350, 600), 0.12, 0.02, seed=rng.randrange(1000)), rng.uniform(0.25, 0.7),
            rng.uniform(0.04, 0.1))
    for _ in range(4):
        add(x, knock(rng.uniform(900, 1500), 0.08, 0.012, seed=rng.randrange(1000)), rng.uniform(0.2, 0.6),
            rng.uniform(0.03, 0.06))
    # Presence: a band-passed crack on the attack plus a wood snap, added after the
    # saturation so they stay crisp, give the blast an edge on laptop speakers; the
    # debris above sits higher (0.9-1.5 kHz) too.
    x = soft_clip(x, 2.0)
    add(x, mul(bandpass(noise(0.12, 59), 1800, 0.7), env_perc(0.12, 0.001, 0.03)), 0.0, 1.8)
    add(x, snap(1400, 58, 0.015), 0.0, 0.5)
    return finish(reverb(x, 0.2, tail=0.5))


def fire_ignite():
    x = whoosh(0.6, 250, 1400, seed=57, peak=0.25, q=0.7)
    add(x, mul([math.sin(TAU * 90 * i / SR) for i in range(frames(0.5))], env_swell(0.5, 0.25)), 0.0, 0.4)
    add(x, crackles(0.65, 18, seed=58, fade_to=0.5), 0.05, 0.6)
    return finish(x)


def fire_burn():
    x = breath(0.4, 500, 350, seed=59)
    add(x, crackles(0.38, 22, seed=60), 0.0, 0.8)
    return finish(x)


def fire_burnout():
    x = breath(1.0, 1200, 160, seed=61, peak=0.15)
    add(x, crackles(0.9, 25, seed=62, fade_to=0.05), 0.0, 0.7)
    add(x, knock(200, 0.3, 0.05, seed=63, click=0.1), 0.12, 0.35)
    return finish(x, fade_out=0.15)


def promotion():
    x = arpeggio([72, 76, 79, 84], 0.07, 0.95, 0.35, 0.55, 0.08)
    add(x, chord([60, 64, 67, 71], 0.75, 0.4), 0.21, 0.5)
    return finish(reverb(x, 0.22, tail=0.3), fade_out=0.15)


def check():
    """Tense but soft: a low minor-second dyad of bowed-ish tones over a dark gong."""
    dur = 1.0
    n = frames(dur)
    tone = [0.0] * n
    for f in (hz(50), hz(51)):
        w = TAU * f / SR
        for i in range(n):
            tone[i] += sum(math.sin(h * w * i) / h for h in range(1, 9))
    tone = mul(lowpass(tone, 1100), env_swell(dur, 0.15, 1.2))
    x = scale(tone, 0.5)
    add(x, bell(hz(38), dur, 0.5, 0.4), 0.0, 0.9)
    add(x, knock(160, 0.3, 0.06, seed=64, click=0.1), 0.0, 0.5)
    # Presence: a small brass ping on D6 (1175 Hz, the dyad's own D) marks the onset on
    # laptop speakers; it decays in ~0.15 s so the swell underneath stays the message.
    add(x, bell(hz(86), 0.5, 0.15, 0.5, attack=0.002), 0.0, 0.3)
    return finish(reverb(x, 0.15, tail=0.3), fade_out=0.1)


def escape():
    x = whoosh(0.45, 400, 1600, seed=65, peak=0.55)
    add(x, bell(hz(69), 0.6, 0.35, 0.4), 0.25, 0.5)
    add(x, bell(hz(76), 0.55, 0.35, 0.4), 0.3, 0.4)
    return finish(reverb(x, 0.18, tail=0.3))


# =============================================================================
# Score, energy, turns
# =============================================================================

def score_tick():
    return finish(bell(hz(83), 0.15, 0.06, 0.4, attack=0.002), fade_out=0.02)


def energy_spend():
    x = mul(glide(620, 420, 0.2, ((1, 1.0), (2, 0.2))), env_perc(0.2, 0.003, 0.06))
    return finish(x)


def energy_refill():
    x = arpeggio([76, 79, 83], 0.06, 0.45, 0.22, 0.35)
    return finish(reverb(x, 0.2, tail=0.25))


def turn_player():
    """Your turn: a clear but gentle rising fifth (G4-D5), soft 8 ms attack."""
    x = bell(hz(67), 0.75, 0.35, 0.4, attack=0.008)
    add(x, bell(hz(74), 0.68, 0.35, 0.4, attack=0.008), 0.08, 0.7)
    # Presence: short octave pings (G5, D6) on each note, gone in ~0.1 s, so "your turn"
    # reads on laptop speakers without turning the chime bright.
    add(x, bell(hz(79), 0.3, 0.1, 0.4, attack=0.004), 0.0, 0.4)
    add(x, bell(hz(86), 0.3, 0.1, 0.4, attack=0.004), 0.08, 0.4)
    return finish(reverb(x, 0.15, tail=0.15), fade_out=0.08)


def turn_opponent():
    """Their turn: it plays every round, so it is a short, dark, almost-felt tap
    (a muted A3 with a whisper of D4), 0.4 s, no ring-out to nag."""
    x = lowpass(bell(hz(57), 0.4, 0.12, 0.15, attack=0.012), 1400)
    add(x, lowpass(bell(hz(62), 0.34, 0.1, 0.1, attack=0.012), 1400), 0.04, 0.35)
    add(x, felt_thud(0.08, 66, 300), 0.0, 0.3)
    return finish(x, fade_out=0.08)


# =============================================================================
# Stingers
# =============================================================================

def _stinger(steps, dur, bells=(), bass=(), gap_tail=0.6):
    """steps: [(time, midis, vel)] Rhodes chords; bells: [(time, midi, gain)];
    bass: [(time, midi)]."""
    x = zeros(dur)
    for t, midis, vel in steps:
        add(x, chord(midis, dur - t, vel), t)
    for t, m, gain in bells:
        add(x, bell(hz(m), dur - t, 0.8, 0.45), t, gain)
    for t, m in bass:
        add(x, upright(hz(m), min(2.0, dur - t), 0.6), t, 0.6)
    return finish(reverb(x, 0.25, tail=gap_tail), fade_out=0.4)


def victory():
    return _stinger([(0.0, [53, 57, 60, 64], 0.5), (0.4, [55, 59, 62, 64], 0.5), (0.8, [52, 55, 59, 62, 64], 0.65)],
                    2.6, bells=[(0.8, 72, 0.4), (0.9, 76, 0.35), (1.0, 79, 0.3)],
                    bass=[(0.0, 41), (0.4, 43), (0.8, 36)])


def defeat():
    return _stinger([(0.0, [53, 57, 60, 64], 0.45), (0.7, [53, 56, 60, 62], 0.4), (1.4, [48, 52, 57, 59], 0.4)],
                    2.8, bells=[(0.0, 69, 0.25), (0.7, 68, 0.22), (1.4, 64, 0.22)],
                    bass=[(0.0, 38), (0.7, 41), (1.4, 33)])


def run_victory():
    return _stinger([(0.0, [53, 57, 60, 64], 0.5), (0.5, [55, 59, 62, 64], 0.55), (1.0, [52, 55, 59, 62, 67], 0.7)],
                    3.4, bells=[(1.0, 72, 0.35), (1.08, 76, 0.33), (1.16, 79, 0.31), (1.24, 83, 0.28),
                                (1.32, 84, 0.3), (1.9, 79, 0.2), (2.0, 84, 0.2)],
                    bass=[(0.0, 41), (0.5, 43), (1.0, 36)], gap_tail=0.4)


def run_defeat():
    return _stinger([(0.0, [57, 60, 64, 67], 0.4), (0.9, [53, 57, 60, 64], 0.38), (1.8, [50, 53, 57, 59], 0.36),
                     (2.5, [48, 52, 57, 59], 0.34)],
                    3.5, bells=[(0.0, 72, 0.2), (0.9, 71, 0.18), (1.8, 69, 0.18), (2.5, 64, 0.2)],
                    bass=[(0.0, 45), (0.9, 41), (1.8, 38), (2.5, 33)], gap_tail=0.3)


def unlock_fanfare():
    x = arpeggio([72, 74, 76, 79, 81, 84], 0.08, 2.6, 0.7, 0.5, 0.05)
    add(x, chord([60, 64, 67, 71, 74], 2.0, 0.55), 0.5, 0.7)
    add(x, bell(hz(88), 2.0, 0.9, 0.3), 0.55, 0.15)
    add(x, upright(hz(36), 2.0, 0.6), 0.5, 0.6)
    return finish(reverb(x, 0.25, tail=0.4), fade_out=0.4)


# =============================================================================
# Map and screens
# =============================================================================

def map_travel():
    x = knock(500, 0.15, 0.025, seed=71, click=0.2)
    add(x, scale(lowpass(paper(0.3, 600, 900, seed=72, peak=0.5), 1500), 0.5), 0.06)
    add(x, knock(420, 0.2, 0.035, seed=73), 0.38, 0.9)
    add(x, felt_thud(0.1, 74, 400), 0.38, 0.5)
    return finish(x)


def screen_transition():
    sweep = lambda p: 200 + 1000 * math.sin(math.pi * p)
    x = mul(lowpass(lowpass(noise(0.5, 75), sweep), sweep), env_swell(0.5, 0.5, 1.5))
    return finish(x, fade_out=0.05)


def reward_reveal():
    x = whoosh(0.4, 300, 1200, seed=76, peak=0.7)
    add(x, arpeggio([67, 71, 74, 79], 0.06, 0.8, 0.45, 0.5, 0.06), 0.25, 0.8)
    return finish(reverb(x, 0.22, tail=0.3))



# =============================================================================
# Music (mono, long seamless loops in sections)
# =============================================================================
#
# Each loop is a little arrangement, not a vamp: A (theme), A' (new voicings,
# comping and an answering phrase, bass pick-ups), B (a bridge with its own
# harmony), a breakdown (keys and bells only) and a turnaround back to A. About
# two minutes each, so a 30-minute session hears each loop ~15 times instead of
# ~45, and no two adjacent minutes sound the same. Mono at 22.05 kHz keeps both
# loops near 11 MB together (stereo would double it for little gain on quiet,
# centred lounge music).

def brush(dur=0.35, seed=0):
    """A soft brush stroke on a snare: swelled filtered noise."""
    x = lowpass(highpass(noise(dur, seed), 900), 3200)
    return mul(x, env_swell(dur, 0.12, 1.0))


def felt_kick(seed=0):
    x = mul(glide(75, 48, 0.25), env_perc(0.25, 0.004, 0.08))
    return add(x, felt_thud(0.06, seed, 200), 0.0, 0.3)


def render_loop(bpm, bars, parts, seed):
    """parts(beat_seconds, n_frames, rng) -> list of (mono, reverb_send).
    Everything is rendered `tail` seconds past the loop end, then the tail is
    wrapped onto the start so the loop is seamless (ring-outs and reverb included)."""
    beat = 60.0 / bpm
    length = frames(bars * 4 * beat)
    tail = frames(4.0)
    total = length + tail
    rng = random.Random(seed)
    mix, send = [0.0] * total, [0.0] * total
    for mono, rev in parts(beat, total, rng):
        for i, v in enumerate(mono[:total]):
            mix[i] += v
            send[i] += v * rev
    wet = _freeverb(lowpass(send, 3000), 0.84, 0.4, 0)
    mix = highpass([a + b for a, b in zip(mix, wet)], 35.0)
    for i in range(tail):
        mix[i] += mix[length + i]
    mix = mix[:length]
    rms = math.sqrt(sum(v * v for v in mix) / length)
    gain = db(MUSIC_RMS_DB) / rms
    peak = max(abs(v) for v in mix) * gain
    if peak > db(PEAK_CEILING_DB):
        gain *= db(PEAK_CEILING_DB) / peak
    return [scale(mix, gain)]


def _at(beat, bar, beats, rng, jitter=0.012):
    """Start time of `beats` into `bar`, nudged late by a few ms (humanised, never early)."""
    return (bar * 4 + beats) * beat + rng.uniform(0.0, jitter)


def _comp(keys, beat, bar, voicing, pattern, rng):
    """Rhodes comping: pattern = [(beat, 'all'|'up', length_beats, hold_beats, vel, gain)]."""
    for beats, notes, length, hold, vel, gain in pattern:
        midis = voicing if notes == "all" else voicing[1:]
        add(keys, chord(midis, length * beat, vel * rng.uniform(0.94, 1.04), 0.015, hold=hold * beat, rng=rng),
            _at(beat, bar, beats, rng), gain)


def _bells(bells, beat, phrases, rng, gain):
    for bar, beats, m in phrases:
        add(bells, bell(hz(m), 2.5, 0.9, 0.35, attack=0.01), _at(beat, bar, beats, rng), gain * rng.uniform(0.85, 1.05))


# --- Menu: "Late table" ---------------------------------------------------------------

DM9, DM9_HI = [53, 57, 60, 64], [60, 64, 65, 69]
G13, G13_HI = [53, 57, 59, 64], [59, 64, 65, 69]
CMAJ9, CMAJ9_HI = [52, 55, 59, 62], [59, 62, 64, 67]
AM9, AM9_HI = [55, 59, 60, 64], [60, 64, 67, 71]
FMAJ9, FMAJ9_HI = [57, 60, 64, 67], [60, 64, 67, 69]
EM7, EM11 = [55, 59, 62, 64], [55, 59, 62, 69]
G9SUS, G9SUS_HI = [53, 57, 60, 62], [60, 62, 65, 69]
FM69 = [56, 60, 62, 67]          # borrowed iv (F minor 6/9): the bridge's colour
A7B9 = [55, 58, 61, 64]
BBMAJ9S11 = [57, 60, 62, 64]
A7SUS = [55, 57, 62, 64]

MENU_BALLAD = [(0, "all", 5.5, 3.6, 0.5, 1.0), (2.5, "up", 2.5, 1.2, 0.3, 0.7)]
MENU_LEAN = [(0, "all", 4.5, 2.8, 0.45, 1.0), (3.5, "up", 2.0, 0.4, 0.28, 0.6)]
MENU_BREATH = [(0, "all", 3.0, 1.8, 0.42, 1.0), (2, "up", 3.5, 1.8, 0.3, 0.7)]
MENU_PAD = [(0, "all", 6.0, 3.9, 0.36, 0.95)]


def music_menu():
    """60 BPM, 32 bars (128 s), D dorian / C major lounge ballad.
    A (8) theme - A' (8) high voicings + answering phrase - B (8) bridge with a
    borrowed F minor - breakdown (4) keys and bells only - turnaround (4)."""
    # (bass root, voicing, comping, bass style)
    bars = [
        # A: the theme
        (38, DM9, MENU_BALLAD, "two"), (43, G13, MENU_BALLAD, "two"), (36, CMAJ9, MENU_BALLAD, "two"),
        (45, AM9, MENU_BALLAD, "two"), (41, FMAJ9, MENU_BALLAD, "two"), (40, EM7, MENU_BALLAD, "two"),
        (38, DM9, MENU_BALLAD, "two"), (43, G9SUS, MENU_BALLAD, "two"),
        # A': same road, higher voicings, leaner comping, bass pick-ups
        (38, DM9_HI, MENU_LEAN, "two"), (43, G13_HI, MENU_BREATH, "two"), (36, CMAJ9_HI, MENU_LEAN, "two"),
        (45, AM9_HI, MENU_BREATH, "pickup"), (41, FMAJ9_HI, MENU_LEAN, "two"), (40, EM11, MENU_BREATH, "two"),
        (38, DM9_HI, MENU_LEAN, "two"), (43, G9SUS_HI, MENU_BREATH, "pickup"),
        # B: bridge
        (41, FMAJ9, MENU_BALLAD, "two"), (41, FM69, MENU_PAD, "long"), (40, EM7, MENU_BALLAD, "two"),
        (45, A7B9, MENU_LEAN, "pickup"), (38, DM9, MENU_BALLAD, "two"), (43, G13, MENU_PAD, "long"),
        (34, BBMAJ9S11, MENU_PAD, "long"), (45, A7SUS, MENU_LEAN, "pickup"),
        # Breakdown: the bass drops out, keys breathe
        (38, DM9_HI, MENU_PAD, "long"), (38, DM9, MENU_PAD, "none"), (34, BBMAJ9S11, MENU_PAD, "none"),
        (43, G9SUS, MENU_PAD, "long"),
        # Turnaround back to the top
        (36, CMAJ9, MENU_BALLAD, "two"), (45, AM9, MENU_LEAN, "two"), (38, DM9, MENU_BALLAD, "two"),
        (43, G9SUS, MENU_LEAN, "pickup"),
    ]
    theme = [(1, 1.0, 76), (1, 2.5, 74), (3, 1.0, 71), (3, 2.0, 72), (5, 1.0, 76), (5, 2.0, 79),
             (5, 3.0, 76), (7, 1.5, 74), (7, 2.5, 72), (7, 3.5, 69)]
    answer = [(9, 1.0, 71), (9, 2.0, 74), (9, 3.0, 76), (11, 1.5, 72), (11, 2.5, 71), (11, 3.0, 67),
              (13, 1.0, 74), (13, 2.5, 71), (15, 1.0, 72), (15, 2.0, 74), (15, 3.5, 77)]
    bridge = [(16, 2.0, 81), (16, 3.0, 79), (17, 1.5, 80), (19, 1.0, 73), (19, 2.5, 70), (21, 1.0, 76),
              (21, 2.0, 74), (22, 1.5, 76), (23, 2.0, 69)]
    sparse = [(25, 2.0, 76), (26, 1.0, 74), (29, 1.0, 76), (31, 2.0, 74)]

    def parts(beat, total, rng):
        keys, bass, bells = [0.0] * total, [0.0] * total, [0.0] * total
        for bar, (root, voicing, pattern, style) in enumerate(bars):
            nxt = bars[(bar + 1) % len(bars)][0]
            _comp(keys, beat, bar, voicing, pattern, rng)
            if style in ("two", "pickup"):
                add(bass, upright(hz(root), 2.2 * beat, 0.7), _at(beat, bar, 0, rng, 0.005))
                add(bass, upright(hz(root + 7), 1.6 * beat if style == "pickup" else 2.2 * beat, 0.5),
                    _at(beat, bar, 2, rng, 0.005), 0.8)
            if style == "pickup":
                add(bass, upright(hz(nxt + (2 if nxt < root + 7 else -1)), 0.7 * beat, 0.45),
                    _at(beat, bar, 3.5, rng, 0.005), 0.7)
            if style == "long":
                add(bass, upright(hz(root), 3.8 * beat, 0.6), _at(beat, bar, 0, rng, 0.005))
        _bells(bells, beat, theme, rng, 0.22)
        _bells(bells, beat, answer, rng, 0.19)
        _bells(bells, beat, bridge, rng, 0.18)
        _bells(bells, beat, sparse, rng, 0.16)
        return [(keys, 0.35), (bass, 0.08), (bells, 0.5)]

    return render_loop(60, len(bars), parts, 6032)


# --- Match: "Quiet clock" -------------------------------------------------------------

E7SUS, E7SUS_HI = [50, 57, 59, 62], [57, 59, 62, 66]
E9, E9_HI = [56, 59, 62, 66], [56, 62, 66, 71]

MATCH_COMP = [(0, "all", 2.5, 1.3, 0.42, 1.0), (1.5, "up", 1.6, 0.4, 0.3, 0.8), (3, "all", 2.0, 0.8, 0.35, 0.85)]
MATCH_LONG = [(0, "all", 3.5, 2.4, 0.4, 1.0), (2.5, "up", 1.5, 0.5, 0.3, 0.75)]
MATCH_PUSH = [(0, "all", 1.8, 0.9, 0.4, 1.0), (2, "up", 1.4, 0.5, 0.3, 0.8), (3.5, "all", 1.8, 0.4, 0.33, 0.8)]
MATCH_PAD = [(0, "all", 4.8, 3.6, 0.34, 0.95)]


def music_match():
    """72 BPM, 36 bars (120 s), A minor modal vamp under the game, no lead melody.
    A (12) the vamp - A' (12) high voicings, varied comping, bass fills, ghost
    brushes - B (8) a lighter two-feel bridge - breakdown (4) pads, no kick."""
    vamp = [(45, AM9), (45, AM9), (41, FMAJ9), (41, FMAJ9), (38, DM9), (38, DM9),
            (45, AM9), (45, AM9), (41, FMAJ9), (38, DM9), (40, E7SUS), (40, E9)]
    hi = {tuple(AM9): AM9_HI, tuple(FMAJ9): FMAJ9_HI, tuple(DM9): DM9_HI, tuple(E7SUS): E7SUS_HI, tuple(E9): E9_HI}
    rotation = [MATCH_COMP, MATCH_LONG, MATCH_PUSH, MATCH_COMP, MATCH_PUSH, MATCH_LONG]
    # (root, voicing, comping, bass style, drum style)
    bars = [(r, v, MATCH_COMP, "walk", "full") for r, v in vamp]
    bars += [(r, hi[tuple(v)], rotation[k % len(rotation)], "fill" if k % 4 == 3 else "walk",
              "fill" if k == 11 else "ghost") for k, (r, v) in enumerate(vamp)]
    bars += [(41, FMAJ9, MATCH_LONG, "two", "light"), (43, G13, MATCH_PUSH, "two", "light"),
             (40, EM7, MATCH_LONG, "two", "light"), (45, AM9, MATCH_PUSH, "two", "light"),
             (38, DM9, MATCH_LONG, "two", "light"), (40, EM7, MATCH_PUSH, "two", "light"),
             (41, FMAJ9, MATCH_LONG, "two", "light"), (40, E7SUS, MATCH_PUSH, "walk", "full")]
    bars += [(45, AM9, MATCH_PAD, "long", "none"), (41, FMAJ9, MATCH_PAD, "long", "none"),
             (38, DM9, MATCH_PAD, "long", "brush"), (40, E9, MATCH_PAD, "long", "fill")]
    phrases_a = [(3, 1.0, 76), (3, 2.0, 72), (7, 1.0, 71), (7, 2.5, 72), (11, 1.0, 71)]
    phrases_b = [(15, 1.0, 79), (15, 2.5, 76), (19, 1.5, 72), (19, 2.5, 74), (23, 1.0, 71), (23, 2.0, 68)]
    phrases_c = [(25, 1.0, 74), (25, 2.0, 71), (27, 1.5, 76), (29, 1.0, 72), (29, 2.0, 69), (31, 2.0, 71),
                 (32, 2.0, 76), (34, 1.0, 72)]

    def parts(beat, total, rng):
        keys, bass, drums, bells = [0.0] * total, [0.0] * total, [0.0] * total, [0.0] * total
        for bar, (root, voicing, pattern, bass_style, drum_style) in enumerate(bars):
            nxt = bars[(bar + 1) % len(bars)][0]
            _comp(keys, beat, bar, voicing, pattern, rng)
            approach = nxt + (1 if nxt < root else -1) if nxt != root else root + 7
            top = root + 12 if root + 12 <= 55 else root + 5
            if bass_style == "walk":
                for b, m in enumerate([root, root + 7, top, approach]):
                    add(bass, upright(hz(m), 1.1 * beat, 0.7 if b % 2 == 0 else 0.5), _at(beat, bar, b, rng, 0.006))
            elif bass_style == "fill":   # walk, then two eighths into the next bar
                for b, m in [(0, root), (1, top), (2, root + 7), (3, nxt + 2), (3.5, approach)]:
                    add(bass, upright(hz(m), 0.9 * beat, 0.6), _at(beat, bar, b, rng, 0.006), 0.9 if b < 3 else 0.7)
            elif bass_style == "two":
                add(bass, upright(hz(root), 2.0 * beat, 0.65), _at(beat, bar, 0, rng, 0.006))
                add(bass, upright(hz(root + 7), 2.0 * beat, 0.5), _at(beat, bar, 2, rng, 0.006), 0.85)
            else:   # long
                add(bass, upright(hz(root), 3.8 * beat, 0.55), _at(beat, bar, 0, rng, 0.006), 0.9)
            seed = bar * 4
            if drum_style in ("full", "ghost", "fill"):
                for b in (0, 2):
                    add(drums, felt_kick(seed + b), _at(beat, bar, b, rng, 0.004), 0.5)
            if drum_style == "light":
                add(drums, felt_kick(seed), _at(beat, bar, 0, rng, 0.004), 0.4)
            if drum_style in ("full", "ghost", "light", "fill"):
                for b in (1, 3) if drum_style != "fill" else (1,):
                    add(drums, brush(0.4, seed + b), _at(beat, bar, b, rng, 0.008) - 0.04,
                        0.13 if drum_style == "light" else 0.18)
            if drum_style == "ghost" and bar % 2:
                add(drums, brush(0.25, seed + 7), _at(beat, bar, 3.5, rng, 0.008) - 0.03, 0.07)
            if drum_style == "fill":   # three brush strokes rising into the next bar
                for k, b in enumerate((3.0, 3.333, 3.667)):
                    add(drums, brush(0.3, seed + 11 + k), _at(beat, bar, b, rng, 0.006) - 0.03, 0.1 + 0.04 * k)
            if drum_style == "brush":
                add(drums, brush(0.5, seed + 3), _at(beat, bar, 3, rng, 0.008) - 0.04, 0.1)
        _bells(bells, beat, phrases_a, rng, 0.15)
        _bells(bells, beat, phrases_b, rng, 0.13)
        _bells(bells, beat, phrases_c, rng, 0.12)
        return [(keys, 0.3), (bass, 0.06), (drums, 0.1), (bells, 0.5)]

    return render_loop(72, len(bars), parts, 7236)


# =============================================================================
# Main
# =============================================================================

SFX = [ui_hover, ui_click, ui_confirm, ui_cancel, ui_error, ui_purchase, ui_toggle, ui_open, ui_close,
       card_draw, card_shuffle, card_play, card_discard, card_select, card_hover,
       piece_pickup, piece_move, piece_land_light, piece_land_medium, piece_land_heavy, capture,
       shield_block, explosion, fire_ignite, fire_burn, fire_burnout, promotion, check, escape,
       score_tick, energy_spend, energy_refill, turn_player, turn_opponent,
       victory, defeat, run_victory, run_defeat, unlock_fanfare,
       map_travel, screen_transition, reward_reveal]
MUSIC = [music_menu, music_match]
# Sounds that play many times a minute get 3 variants: <id>.wav, <id>_2.wav, <id>_3.wav.
# Keep in sync with config/ux.json audio.sounds[id].variants (check.py verifies the files).
VARIANTS = {ui_hover: 3, ui_click: 3, card_draw: 3, card_hover: 3, piece_pickup: 3, piece_move: 3,
            piece_land_light: 3, piece_land_medium: 3, piece_land_heavy: 3, capture: 3}


def main(only):
    for fn in SFX:
        if only and fn.__name__ not in only:
            continue
        for v in range(VARIANTS.get(fn, 1)):
            x = fn(v) if v else fn()
            name = fn.__name__ + ("_%d" % (v + 1) if v else "")
            write_wav(os.path.join(SFX_DIR, name + ".wav"), [x])
            print("sfx   %-20s %5.2f s" % (name, len(x) / SR))
    for fn in MUSIC:
        if only and fn.__name__ not in only:
            continue
        channels = fn()
        write_wav(os.path.join(MUSIC_DIR, fn.__name__ + ".wav"), channels)
        print("music %-20s %5.2f s" % (fn.__name__, len(channels[0]) / SR))


if __name__ == "__main__":
    main(set(sys.argv[1:]))

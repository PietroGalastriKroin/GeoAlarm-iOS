#!/usr/bin/env python3
"""Gera o ícone do app e os sons de alarme embutidos, só com a biblioteca padrão.

Uso (na raiz do repositório):  python tools/generate_assets.py
Saída:
  GeoAlarm/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png
  GeoAlarm/Resources/Sounds/*.wav   (16-bit PCM, 44.1 kHz, mono)
"""
import math
import os
import struct
import wave
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RATE = 44100


# --------------------------------------------------------------------------- sons

def envelope(t, attack=0.005, decay=0.25):
    if t < attack:
        return t / attack
    return math.exp(-(t - attack) / decay)


def tone(freq, dur, attack=0.005, decay=0.25, harmonics=((1, 1.0),)):
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        s = sum(a * math.sin(2 * math.pi * freq * h * t) for h, a in harmonics)
        out.append(s * envelope(t, attack, decay))
    return out


def silence(dur):
    return [0.0] * int(RATE * dur)


def mix_at(buf, samples, start):
    s = int(RATE * start)
    need = s + len(samples)
    if need > len(buf):
        buf.extend([0.0] * (need - len(buf)))
    for i, v in enumerate(samples):
        buf[s + i] += v


def write_wav(name, samples, gain=0.85):
    peak = max(1e-9, max(abs(v) for v in samples))
    scale = gain / peak
    path = os.path.join(ROOT, "GeoAlarm", "Resources", "Sounds", name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v * scale)) * 32767)) for v in samples))
    print("sound", path, round(len(samples) / RATE, 1), "s")


def alvorada():
    buf = []
    notes = [523.25, 659.25, 783.99, 1046.5]
    for rep in range(3):
        base = rep * 3.0
        for i, f in enumerate(notes):
            mix_at(buf, tone(f, 0.9, decay=0.35, harmonics=((1, 1.0), (2, 0.3))), base + i * 0.22)
    buf.extend([0.0] * (int(RATE * 9.0) - len(buf)))
    return buf


def sirene():
    n = int(RATE * 8.0)
    out, phase = [], 0.0
    for i in range(n):
        t = i / RATE
        f = 600 + 500 * (0.5 + 0.5 * math.sin(2 * math.pi * t / 1.6 - math.pi / 2))
        phase += 2 * math.pi * f / RATE
        out.append(math.sin(phase) + 0.25 * math.sin(2 * phase))
    return out


def bip_classico():
    buf = []
    for rep in range(8):
        base = rep * 1.0
        for k in range(3):
            mix_at(buf, tone(1800, 0.12, attack=0.002, decay=0.5), base + k * 0.18)
    buf.extend([0.0] * (int(RATE * 8.0) - len(buf)))
    return buf


def sino():
    buf = []
    partials = ((1, 1.0), (2.76, 0.6), (5.4, 0.35), (8.93, 0.2))
    for rep in range(4):
        mix_at(buf, tone(660, 2.0, attack=0.002, decay=0.7, harmonics=partials), rep * 2.0)
    buf.extend([0.0] * (int(RATE * 8.0) - len(buf)))
    return buf


def radar():
    buf = []
    for rep in range(6):
        mix_at(buf, tone(1200, 1.4, attack=0.003, decay=0.28, harmonics=((1, 1.0), (2, 0.12))), rep * 1.3)
    buf.extend([0.0] * (int(RATE * 8.0) - len(buf)))
    return buf


def pulso():
    buf = []
    for rep in range(8):
        base = rep * 1.0
        mix_at(buf, tone(440, 0.35, decay=0.5, harmonics=((1, 1.0), (3, 0.2))), base)
        mix_at(buf, tone(880, 0.35, decay=0.5, harmonics=((1, 1.0), (3, 0.2))), base + 0.4)
    buf.extend([0.0] * (int(RATE * 8.0) - len(buf)))
    return buf


def sounds():
    write_wav("alvorada.wav", alvorada())
    write_wav("sirene.wav", sirene(), gain=0.7)
    write_wav("bip_classico.wav", bip_classico())
    write_wav("sino.wav", sino())
    write_wav("radar.wav", radar())
    write_wav("pulso.wav", pulso())


# --------------------------------------------------------------------------- ícone

def png_bytes(w, h, rgb_rows):
    raw = b"".join(b"\x00" + bytes(row) for row in rgb_rows)

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def lerp(a, b, t):
    return a + (b - a) * t


def icon():
    size = 1024
    ss = 2  # supersampling por eixo
    cx, cy = size / 2, size / 2 + 20
    top, bot = (74, 128, 255), (24, 52, 168)
    rows = []
    for y in range(size):
        row = bytearray()
        for x in range(size):
            acc = [0.0, 0.0, 0.0]
            for sy in range(ss):
                for sx in range(ss):
                    px, py = x + (sx + 0.5) / ss, y + (sy + 0.5) / ss
                    t = py / size
                    r, g, b = (lerp(top[i], bot[i], t) for i in range(3))
                    d = math.hypot(px - cx, py - cy)
                    # anéis de geofence
                    for rad, w in ((400, 14), (290, 14)):
                        if abs(d - rad) < w:
                            k = 0.55 if rad == 400 else 0.8
                            r, g, b = lerp(r, 255, k), lerp(g, 255, k), lerp(b, 255, k)
                    # pino: círculo + ponta
                    pin_cx, pin_cy, pin_r = cx, cy - 70, 120
                    inside = math.hypot(px - pin_cx, py - pin_cy) < pin_r
                    if not inside and pin_cy < py < pin_cy + 215:
                        half = pin_r * (1 - (py - pin_cy) / 215) * 0.9
                        inside = abs(px - pin_cx) < half and py > pin_cy
                    if inside:
                        r, g, b = 255, 255, 255
                        if math.hypot(px - pin_cx, py - pin_cy) < 48:
                            r, g, b = top
                    acc[0] += r
                    acc[1] += g
                    acc[2] += b
            n = ss * ss
            row += bytes((int(acc[0] / n), int(acc[1] / n), int(acc[2] / n)))
        rows.append(row)
    out = os.path.join(ROOT, "GeoAlarm", "Resources", "Assets.xcassets", "AppIcon.appiconset", "icon-1024.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "wb") as f:
        f.write(png_bytes(size, size, rows))
    print("icon", out)


if __name__ == "__main__":
    sounds()
    icon()

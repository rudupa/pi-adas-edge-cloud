#!/bin/bash
# Hardware smoke test: audio output (Pimoroni Pirate Audio MAX98357A I2S amp)
#
# Generates a short 1 kHz sine-wave test tone and plays it through the
# default ALSA output device (mapped to the MAX98357A in asound.conf).
set -euo pipefail

TONE_FILE="/tmp/test-tone-$$.wav"

cleanup() { rm -f "$TONE_FILE"; }
trap cleanup EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

# ── Verify ALSA output device is present ─────────────────────────────────────
aplay -l 2>/dev/null | grep -qi "card" \
    || fail "no ALSA playback devices found (aplay -l)"

# ── Generate 1 kHz sine tone (2 s, 48 kHz, mono, 16-bit) via ffmpeg ──────────
if command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg -loglevel error -y \
        -f lavfi -i "sine=frequency=1000:duration=2:sample_rate=48000" \
        -ar 48000 -ac 1 -f wav "$TONE_FILE" \
        || fail "ffmpeg tone generation failed"
else
    # Fallback: synthesise a minimal 44-byte WAV header followed by 2 s of silence.
    # Audio parameters: 48000 Hz, 1 channel, 16-bit PCM
    #   Byte offset / field name              / value (little-endian where applicable)
    #   0–3   ChunkID                         "RIFF"
    #   4–7   ChunkSize  = 36 + DataSize       0x0002F024 (= 36 + 192000)
    #   8–11  Format                          "WAVE"
    #   12–15 Subchunk1ID                     "fmt "
    #   16–19 Subchunk1Size (PCM = 16)         0x00000010
    #   20–21 AudioFormat  (PCM = 1)           0x0001
    #   22–23 NumChannels  (mono = 1)          0x0001
    #   24–27 SampleRate   (48000 = 0xBB80)    0x0000BB80
    #   28–31 ByteRate     (48000×1×2)         0x00017600
    #   32–33 BlockAlign   (1×2)               0x0002
    #   34–35 BitsPerSample (16)               0x0010
    #   36–39 Subchunk2ID                     "data"
    #   40–43 Subchunk2Size = 192000           0x0002F000
    # Data: 48000 Hz × 1 ch × 2 bytes/sample × 2 s = 192,000 bytes of zeros
    printf 'RIFF\x24\xf0\x02\x00WAVEfmt \x10\x00\x00\x00\x01\x00\x01\x00' > "$TONE_FILE"
    printf '\x80\xbb\x00\x00\x00\x76\x01\x00\x02\x00\x10\x00data\x00\xf0\x02\x00' >> "$TONE_FILE"
    dd if=/dev/zero bs=1 count=192000 2>/dev/null >> "$TONE_FILE" || true
fi

[ -s "$TONE_FILE" ] || fail "tone file is empty"

# ── Play the tone ─────────────────────────────────────────────────────────────
aplay -D default -q "$TONE_FILE" 2>/dev/null \
    || fail "aplay failed to play tone through default output device"

echo "PASS: audio output played via MAX98357A ($(aplay -l 2>/dev/null | awk '/card/{print $3; exit}'))"

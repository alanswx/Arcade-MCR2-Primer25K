# Bench wiring — Tang Console 60K (current bitstream)

What the **bitstreams in `bitstreams/` actually drive today**. Generated from
`mcr2_console60k/src/mcr2_console60k.cst`; if you change the CST, update this.

> **Do not wire from `universal_mcr_shield_spec.md` §4b.** That is the future
> shield's cabinet-connector plan and deliberately differs from these
> desk-test assignments. §4a of that doc is still the authority for which
> FPGA ball a J10 pin reaches; this page is which *signal* is on it now.

## Finding pin 1 on J10

J10 is the 2×20 header **nearest the PMOD sockets** (the other one, J9, is
the SDRAM slot — leave it alone). Odd pins are one row, even the other, so
pins 1/2 face each other, 3/4, and so on.

**Anchor electrically, don't count from the end:** with the board powered,
find the pair reading **+5 V and GND** — that is pins **11 and 12**, the
sixth pair. Count from there. Pin 12 is your ground for everything below.

## Current J10 map

| J10 pin | Signal | Notes |
|---:|---|---|
| 1, 2, 3, 4 | `vga_r[0..3]` | red, LSB→MSB |
| 5, 6, 7, 8 | `vga_b[0..3]` | blue, LSB→MSB |
| 11 | **+5 V** | supply *out*; do not back-feed (see TODO) |
| 12 | **GND** | reference for everything |
| 13, 14, 15, 16 | `vga_g[0..3]` | green, LSB→MSB |
| 17 | `vga_hs` | HSync — carries **CSYNC** in 15 kHz mode |
| 18 | `vga_vs` | VSync |
| 21 | `debug_o[0]` | DDR3 calibration done — steady 3.3 V = trained |
| 22 | `debug_o[1]` | pixel-clock heartbeat — should bounce ~1 Hz |
| 23 | `debug_o[2]` | 27 MHz reference heartbeat — bounces ~0.8 Hz |
| 24 | `debug_o[3]` | DDR reset — steady LOW when healthy |
| 35 | `audio_l` | PWM, needs an RC filter before an amp |
| 36 | `audio_r` | PWM |
| 37 | `mode15_n` | **open = 31 kHz**, jumper to GND = 15 kHz |
| 39 | sync format | 15 kHz: open = separate H/V (default), GND = composite sync on HS |
| 40 | VSync enable | 15 kHz: open = VS driven, GND = VS held inactive |

Everything else on J10 is unassigned in the current bitstream.

## Analogue video, option A — DE-15 breakout + 9 resistors

Cheapest and least ambiguous: a screw-terminal VGA breakout, no active
parts, and it doubles as a prototype of the shield's video DAC.

Use only the **top three bits** of each colour (`[3:1]`) — bit 0 is just an
MSB copy for the 4-bit Pmod, so leave `vga_*[0]` unconnected.

| VGA pin | From J10 pins (MSB→LSB) | Through |
|---|---|---|
| 1 (Red) | 4, 3, 2 | 510 Ω, 1 kΩ, 2 kΩ — join at the terminal |
| 2 (Green) | 16, 15, 14 | 510 Ω, 1 kΩ, 2 kΩ |
| 3 (Blue) | 8, 7, 6 | 510 Ω, 1 kΩ, 2 kΩ |
| 13 (HSync) | 17 | direct (or ~100 Ω) |
| 14 (VSync) | 18 | direct |
| 5,6,7,8,10 (GND) | 12 | direct |

560 Ω / 1.1 k / 2.2 k are fine substitutes.

## Analogue video, option B — Digilent PmodVGA

**The Rev C PmodVGA is not passive.** It has two SN74ALVC245 buffers that
must be powered or it outputs nothing:

- **Feed VCC 3.3 V** (J1 pin 6 or 12, and J2 pin 6 or 12).
- **Never 5 V** — the ALVC245's absolute maximum supply is ~4.6 V, so J10
  pin 11 would risk damaging the module. Take 3.3 V from a PMOD socket's
  3V3 pin.

Jumper recipe (J10 → Pmod):

| J10 | PmodVGA |
|---|---|
| 1,2,3,4 | J1 pins 1,2,3,4 (R0–R3) |
| 5,6,7,8 | J1 pins 7,8,9,10 (B0–B3) |
| 13,14,15,16 | J2 pins 1,2,3,4 (G0–G3) |
| 17 | J2 pin 7 (HS) |
| 18 | J2 pin 8 (VS) |
| 12 | J1 pin 5 and J2 pin 5 (GND) |
| 3V3 from a PMOD socket | J1 pin 6 and J2 pin 6 (VCC) |

**Plugging the Pmod straight into the two PMOD sockets is not currently
supported.** Sipeed's socket pin order is not Digilent's, and the two straps
that used to resolve that mapping (J10-39/40) were repurposed for the 15 kHz
sync format, which turned out to matter more. The jumper recipe above works
regardless of socket orientation.

## 15 kHz vs 31 kHz

- **J10-37 open** → 31 kHz progressive, works on any VGA monitor.
- **J10-37 to GND** → native 15 kHz arcade timing (15.77 kHz; displays
  usually report it as "16 kHz", which is correct). Needs an arcade CRT,
  multisync, or an OSSC/RetroTink — an ordinary VGA LCD will not sync, which
  is expected rather than a fault.

### 15 kHz sync format (J10-39 / J10-40)

Displays disagree about what a 15 kHz source should look like, so the format
is strap-selectable rather than baked in:

| J10-39 | J10-40 | Output at 15 kHz |
|---|---|---|
| open | open | **separate H and V sync — default**, and what a real MCR cabinet uses (Video pins 8 and 9) |
| GND | open | composite sync on HS (RGBS) — for an OSSC/RetroTink or SOG-wired monitor |
| GND | GND | composite sync on HS, VS inactive — single-sync RGBS |
| open | GND | separate H sync, VS inactive |

31 kHz always uses separate H/V regardless of these straps.

**If a display drops a whole colour channel at 15 kHz** (green vanishing is
the classic symptom — greys turn magenta, olive turns purple, red and blue
stay correct), it has mis-detected the sync format, not lost a wire: the
FPGA drives all three channels through identical logic and cannot lose one
on its own. Composite sync used to be the default here and provoked exactly
that on a 15 kHz-capable LCD. **Displays latch their format detection**, so
switching format while the signal is live often will *not* re-trigger it —
disturb sync or power-cycle the display between attempts, or the test looks
like it failed when it did not.

HDMI keeps working in both modes (the framebuffer captures whatever the core
emits), so you always have a reference picture.

## No wiring needed

- **HDMI** — onboard connector.
- **USB gamepad** — left USB-A port. **Select+Start opens the game-select
  OSD** (Up/Down move, A loads from the SD pack, B exits). The screen
  freezing (HDMI) or dropping sync (VGA) for ~1 s after pressing A is the
  reload, not a crash.
- **MicroSD** (ROM loading) — onboard slot.
- **Status beacon** — USB-C serial, 115200 8N1: `FB c_ r_ x____ q__ d__ L__`
  (DDR calib, DDR reset, pixel-clock counter, 27 MHz counter,
  d = game_id[2:0] in the high 3 bits + capture delay in the low 5,
  loader state).

# Bally Midway MCR2 Arcade Core for Gowin Tang FPGAs

Standalone port of the Bally Midway MCR-2 arcade hardware (Tron, Domino
Man, Satan's Hollow, Wacko, Kozmik Kroozr, Two Tigers) for Sipeed Tang
FPGA boards — no MiSTer/HPS required. The flagship target is the **Tang
Console 60K**: all six games in one bitstream, selected at runtime from an
on-screen menu, with ROMs loaded from a microSD card.

| Board | Status |
|---|---|
| **Tang Console 60K** (GW5AT-60) | All six games + OSD menu; 720p HDMI with audio (DDR3 framebuffer); analog RGB at 31/15 kHz for real cabinets; USB gamepad; SD ROM loading |
| Tang Primer 25K (GW5A-25) | Domino Man over HDMI (single game per build, BSRAM-limited) |
| Tang Console 138K (GW5AST-138) | Stale — needs the 60K backport |

New here? Read [handoff_v4_60k_multicore.md](handoff_v4_60k_multicore.md)
for the current platform state and family runway.

Deeper docs: build gotchas and architecture notes in [CLAUDE.md](CLAUDE.md),
open issues in [TODO.md](TODO.md), bench hookup in
[docs/bench_wiring.md](docs/bench_wiring.md), cabinet shield spec in
[docs/universal_mcr_shield_spec.md](docs/universal_mcr_shield_spec.md),
porting plan for the other MCR generations in
[docs/mcr_core_roadmap.md](docs/mcr_core_roadmap.md).

---

## 1. Generate the ROM hex tables

ROM zips (MAME sets) go in `roms/` — they are **not** in the repo. Then,
from the repo root:

```sh
python3 tools/merge_roms.py tron     # or domino / shollow / wacko / kroozr / twotiger
```

This writes the `rom_*.hex` tables the build bakes into BSRAM and sets the
board's `game_config.vh`. On the 60K the baked game only decides **what
boots with no SD card** — every game is reachable at runtime from the OSD.

## 2. Build

Headless (recommended; macOS paths shown — see CLAUDE.md for why the IDE
flow needs extra care):

```sh
GWLIB=/Applications/GowinIDE.app/Contents/Resources/Gowin_EDA/IDE/lib
GW=/Applications/GowinIDE.app/Contents/Resources/Gowin_EDA/IDE/bin/gw_sh
cd mcr2_console60k
DYLD_LIBRARY_PATH="$GWLIB" DYLD_FRAMEWORK_PATH="$GWLIB" "$GW" build.tcl
```

The bitstream lands at `mcr2_console60k/impl/pnr/mcr2_console60k.fs`.
Prebuilt images for all six games are kept in `bitstreams/`.

IDE builds work too (open `mcr2_console60k/mcr2_console60k.gprj`, Run All)
but several project settings must be exactly right — read the Gotchas
table in CLAUDE.md first; in particular **Place & Route → Place Option
must be 2** or HDMI silently dies.

## 3. Flash the board

With [openFPGALoader](https://github.com/trabucayre/openFPGALoader)
(`brew install openfpgaloader`), board connected over USB-C:

```sh
# quick test - loads SRAM, lost at power-off
openFPGALoader -b tangconsole bitstreams/console60k_tron.fs

# make it the POWER-ON default - writes the SPI flash
openFPGALoader -b tangconsole -f bitstreams/console60k_tron.fs
```

The `-f` form replaces whatever was in flash (e.g. NESTang) — reflash that
the same way if you want it back. The Gowin Programmer GUI works as well
(External Flash Mode → exFlash Erase, Program).

## 4. Make the SD card (all six games, switchable from the menu)

The ROM pack lives in **raw sectors starting at sector 2048** (1 MiB in) —
no filesystem involved, and it coexists with a normally-formatted card
(standard SD formatting starts the first partition at 4 MiB+; existing
files are untouched).

```sh
python3 tools/make_rompack.py                 # builds mcr_rompack.img from roms/
sudo python3 tools/write_rompack.py           # lists candidate cards
sudo python3 tools/write_rompack.py disk4     # writes + verifies (macOS)
```

`write_rompack.py` refuses to touch anything that is not a removable disk,
refuses cards whose partitions would overlap the pack, and verifies the
header after writing. On Linux/Windows use the `dd`/Win32DiskImager recipe
that `make_rompack.py` prints.

Put the card in the **console's** microSD slot. Every game you select in
the OSD is saved to the card (a reserved sector below the pack), and the
next power-on boots straight back into it - so a cabinet owner picks a
game once and it sticks. With no card (or a blank prefs sector) the
baked-in game boots.

## 5. Play

- **USB gamepad** in the left USB-A port: D-pad = joystick, A = Button 1,
  Start = Start 1, Select = Coin 1 (B/X/Y vary per game — see the input
  maps in `mcr2_console60k_top.sv`).
- **Select+Start opens the game-select menu** on every video output:
  Up/Down move, A loads the highlighted game from the SD card, B exits.
  The screen freezing (HDMI) or dropping sync (analog) for ~1 s after
  pressing A is the ROM reload, not a crash.
- Board keys: AA13 = reset, AB13 = Coin 1.
- HDMI is always live at 720p. Analog RGB comes out of the J10 header
  (31 kHz VGA, or jumper J10-37 to GND for native 15 kHz arcade timing) —
  wiring recipes in [docs/bench_wiring.md](docs/bench_wiring.md).
- A UART status beacon prints on the USB-C serial port (115200 8N1) for
  case-closed debugging — field decoding in docs/bench_wiring.md.

## 6. Cabinet integration

The goal is a drop-in board for real MCR cabinets: analog 15 kHz RGB,
original harness connectors, physical DIPs for game options. For anyone
building the PCB: the **frozen 40-pin header sheet is
[docs/shield_j10_pinout.md](docs/shield_j10_pinout.md)** — one header
carries video, audio and all controls (inputs via a 74HC165 chain that
covers every game, outputs via 74HC595). The consolidated electrical spec
is [docs/universal_mcr_shield_spec.md](docs/universal_mcr_shield_spec.md);
per-game harness pinouts are in
[docs/mcr_game_input_matrix.md](docs/mcr_game_input_matrix.md).

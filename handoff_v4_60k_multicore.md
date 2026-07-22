# MCR Port V4 Handoff — Tang Console 60K multi-core arcade platform

**Most current handoff.** Supersedes `handoff_v3_video_and_domino.md` (the
Tang Primer 25K HDMI bring-up + Domino POC — now historical; every "path
forward" it listed is done). This describes the 60K as it stands: a
multi-game MCR arcade platform with a clear runway to the whole MCR family.

Detail lives in the docs this file points at; this is the map.

---

## 1. What works today (Tang Console 60K)

- **Six MCR-2 games in one bitstream** — Domino Man, Tron, Satan's Hollow,
  Wacko, Kozmik Kroozr, Two Tigers — selected at runtime from an on-screen
  menu. Verified on hardware: HDMI, analog video, USB pad, SD game
  switching, and boot-into-last-game all work.
- **720p HDMI with audio** from a DDR3-backed framebuffer (nand2mario/
  gbatang), fully decoupled from core timing (no shimmer, no genlock).
- **Analog RGB** on the J10 header at native 31 kHz and 15 kHz (real
  cabinet timing), strap-selectable sync format.
- **USB HID gamepad** on USB-A port 1, with a cold-boot recovery fix so it
  enumerates from a flash boot (not just a JTAG load).
- **SD ROM loader + preferences**: games load from a raw-sector pack on a
  microSD card; the selected game persists to a reserved sector, so a
  cabinet boots straight back into the owner's last choice.
- **On-screen menu (`src/rtl/osd.sv`)** composited in the core raster
  domain, so it shows identically on HDMI and analog, rotated for the
  vertical games. Parameterized per family (game count, names, rotation).

Everything here is on `main`. Prebuilt flashable images are in
`bitstreams/` (`console60k_<game>.fs`).

## 2. How to drive it

Full build / flash / SD-card / play instructions are in **`README.md`**
(§1–5). The short version:

```sh
python3 tools/merge_roms.py tron            # generate ROM hex for a game
cd mcr2_console60k && gw_sh build.tcl        # headless build (see CLAUDE.md)
openFPGALoader -b tangconsole -f bitstreams/console60k_tron.fs   # flash to boot
python3 tools/make_rompack.py                # build the SD pack (all MCR-2 games)
sudo python3 tools/write_rompack.py diskN    # write it to a card (guarded)
```

On the pad: **Select+Start opens the game menu**; Up/Down move, A loads, B
exits. Bench wiring (analog video, straps, LEDs, beacon) is in
**`docs/bench_wiring.md`**.

## 3. Architecture notes (the load-bearing decisions)

These are the things that cost real debugging; the full "do not regress"
list is in **`CLAUDE.md`**. Highlights:

- **PLL VCO must stay 700–1400 MHz** — the original rolling-screen bug.
- **HDMI is one clock chain** (27 MHz → PLL → 371.25 → CLKDIV÷5 → 74.25),
  NESTang-style; gbatang's cross-PLL serializer clocking produced
  synced-but-dead TMDS here.
- **Declare-before-use, always** — Gowin turns use-before-declaration into
  a silent 1-bit wire (post-build check greps for "Undeclared symbol").
- **IDE Place Option must be 2** or DDR3 never trains → black HDMI.
- The video pipeline splits *after* the OSD composite, so the menu (and any
  future overlay) is on every output for free.

## 4. The MCR family runway

The plan and per-phase design live in **`docs/mcr_core_roadmap.md`**,
grounded in the five MiSTer MCR cores vendored under `refs/` (gitignored).
Status at this handoff:

| Family | Games | Status |
|---|---|---|
| **MCR-2** | the six above | **Shipping on hardware** |
| **MCR-1** | Kick, Kickman, Solar Fox | **Builds** (`mcr1_console60k/`, `console60k_mcr1_*.fs`); no new HW; not yet hardware-tested |
| **SDRAM foundation** | — | **Memtest built** (`console60k_sdram_memtest.fs`); verifies the J9 module before any core rides it. Gate for all MCR-3 |
| **MCR-3** | Tapper, Timber, Journey, DoT | **Core vendored + adapted** (`src/rtl/mcr3.vhd`); board integration fully designed, gated on the SDRAM memtest passing |
| **MCR3Scroll** | Spy Hunter, Crater, Turbo Tag | **Core vendored + adapted** (`src/rtl/mcr3scroll.vhd`); FX68K sound stack verified portable; board gated on SDRAM |
| **MCR3Mono** | Rampage, Sarge, Max RPM, … | **Core vendored + adapted** (`src/rtl/mcr3mono.vhd`); TCS (6809) + Sounds Good (FX68K) verified portable; board gated on SDRAM |

Key realities the roadmap captures:
- MCR-1 needs **no new hardware** (small ROMs, all BRAM) — the cheap win.
- Every MCR-3 family needs the **Tang SDRAM module in J9** for the 128 KB
  real-time sprite ROM (won't fit BRAM). That's why the SDRAM memtest
  comes first — verify the memory in isolation, then build cores on it.
- **Journey's tape samples go in DDR3** (the framebuffer's), not the sprite
  SDRAM. **Discs of Tron** ships without speech (Squawk & Talk was never
  implemented upstream).

## 5. Hardware verification status (what's proven vs pending)

| Item | Status |
|---|---|
| 60K HDMI 720p + audio | ✅ on hardware |
| Analog 31/15 kHz | ✅ on hardware |
| USB pad + cold-boot fix | ✅ on hardware |
| SD loader + boot-into-last-game | ✅ on hardware |
| OSD menu (all 6 MCR-2 games) | ✅ on hardware |
| MCR-1 (Kick/Solar Fox) | ⏳ builds, flash + play pending |
| SDRAM module (J9) | ⏳ memtest built, module in hand, test scheduled |
| MCR-3 board | ⛔ blocked on the SDRAM memtest |

Per-game control caveats (derived, not yet play-tuned): Kick spinner
sensitivity; Tron aim direction (MAME PORT_REVERSE); Kroozr/Wacko/Two
Tigers analogue feel; the cap_delay left-edge value. All in `TODO.md`.

## 6. Shield / cabinet integration

The PCB is being built. The authoritative sheet is
**`docs/shield_j10_pinout.md`** — one 40-pin J10 header carries video,
audio and *all* controls: cabinet inputs and both DIP banks ride a
7×74HC165 chain (3 pins), outputs a 74HC595+ULN2803 chain (4 pins). The
input stage is **74AHC165 at 3.3 V taking the 5 V harness directly** (no
level-shifter ICs, no optos — the buck is non-isolated, so the optos never
bought isolation anyway). Electrical spec and per-game harness maps:
`docs/universal_mcr_shield_spec.md`, `docs/mcr_game_input_matrix.md`.

The shield's "live" pins are exactly what today's bitstreams drive, so the
board does video/audio the day it's soldered; the control-chain pins are
reserved and wait on the expander RTL (a small, planned module — `TODO.md`).

**Interface style (settled 2026-07-22): the cabinet harness plugs into the
shield** — the shield presents the original MCR connectors, the operator
plugs the existing harness in and picks the game in the OSD, and the FPGA
maps every pin per game (no rewiring). Not a mechanical board-swap. Rev A
targets the SSIO-family connectors (most games); MCR3Mono is a later
variant (spec §0).

## 7. Immediate next steps

1. **Flash the SDRAM memtest** with the module in J9; watch the J10 LEDs
   (PASS/DONE/FAIL/heartbeat). DONE+PASS unblocks all of MCR-3. If reads
   fail, swap the ODDR D0/D1 phase in `src/rtl/sdram_gw.sv` and rebuild.
2. **Then build the MCR-3 board** (Tapper first) per the settled design in
   the roadmap — vendored core + proven memory make it mechanical.
3. **Play-test MCR-1** (flash `console60k_mcr1_kick.fs`) whenever
   convenient; it needs no SDRAM.
4. Continue the family: MCR3Scroll and MCR3Mono (they add FX68K / 6809
   sound boards on top of the same SDRAM foundation).

## 8. Doc map

- `README.md` — build / flash / SD / play, front to back.
- `CLAUDE.md` — build gotchas + the "do not regress" constraints.
- `TODO.md` — every open item, consolidated.
- `docs/mcr_core_roadmap.md` — the MCR family porting plan (Phases A–E).
- `docs/shield_j10_pinout.md` — the frozen 40-pin shield header.
- `docs/universal_mcr_shield_spec.md` — shield electrical spec.
- `docs/mcr_game_input_matrix.md` — per-game harness + SSIO bit maps.
- `docs/bench_wiring.md` — what the current bitstream drives on J10.
- `handoff_v3_video_and_domino.md` — the 25K HDMI/Domino bring-up (historical).
- `handoff_v2_design.md` — original SDRAM/V2 plan + shield electrical spec.

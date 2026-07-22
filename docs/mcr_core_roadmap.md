# MCR family porting plan (Tang Console 60K)

Rewritten 2026-07 after vendoring the five MiSTer MCR cores into `refs/`
(local reference checkouts, gitignored — nested git repos). This replaces
the earlier speculative roadmap: everything below is verified against the
actual sources.

## What the survey established

All five cores are the same dar/sorgelig lineage as our `mcr2.vhd` — one
core `.vhd` each, identical support files (T80, Z80CTC, `dpram`,
`gen_ram`, `cmos_ram`, `spinner.sv`), the **same `clock_40` input, the
same external CPU/sound ROM ports, and the same `dl_` download bus** our
SD loader already drives. The 60K platform (framebuffer/HDMI, analog
video, OSD, SD loader+prefs, USB, beacon, shield header) carries over
unchanged for every family.

| refs/ core | Games (from the MRAs) | Sound | ROM home on MiSTer |
|---|---|---|---|
| Arcade-MCR1 | Kick, Solar Fox | SSIO (same `mcr_sound_board.vhd` we ship) | **all BRAM** — no sdram.sv in the repo |
| Arcade-MCR3 | Tapper, Timber, Journey, Discs of Tron | SSIO + `wave_sound.sv` sample player (Journey tape music; **DoT speech absent upstream** — Squawk & Talk was never implemented) | CPU+sound+sprites in SDRAM, bg (32 KB) via `dl_` into BRAM |
| Arcade-MCR3Scroll | Spy Hunter, Crater Raider, Turbo Tag | SSIO + Cheap Squeak Deluxe (`cheap_squeak_deluxe.vhd`, FX68K) | SDRAM |
| Arcade-MCR3Mono | Rampage, Sarge, Max RPM, Power Drive, Star Guards, Demolition Derby (mono) | Turbo Cheap Squeak (`cpu09l` 6809) / Sounds Good (FX68K) — no SSIO | SDRAM |

Memory reality on the 60K (118 BSRAM blocks, ~78 free ≈ 156 KB for game
ROM after platform + core RAM):

- **MCR-1 fits BRAM trivially** (Kick ≈ 50 KB, Solar Fox ≈ 80 KB;
  `cpu_rom_addr` is only 15 bits). No new memory hardware.
- **Every MCR-3 family needs the SDRAM module** — sprite ROM alone is
  128 KB (Tapper) to 256 KB (Rampage); MiSTer's own `sdram.sv` multi-port
  arcade controller is in each refs/ repo, purpose-built for these cores.

## Phase A — MCR-1 core: Kick, Kickman, Solar Fox   [IN PROGRESS]

**Status 2026-07: the core builds.** `src/rtl/mcr1.vhd` vendored + patched
(hcnt_out/vcnt_out exposed; three gfx dprams given INIT_FILE and explicit
we_a/we_b tie-offs, since our SV dpram has no VHDL port defaults). New
`mcr1_console60k/` board project (MCR-2 top with the core swapped: 15-bit
CPU ROM + MCR-1 download map, 4-bit RGB truncated to the shared 3:3:3
pipeline, per-game input mux). merge_roms grew `family`-aware output and
kick/kickman/solarfox specs; osd.sv parameterized for the 2-game roster.
Kick: BSRAM 77/118, setup +0.585 ns. Bitstreams in `bitstreams/`
(console60k_mcr1_kick.fs, console60k_mcr1_solarfox.fs). **Not yet flashed
/ hardware-verified**; SD pack switching waits on pack-v2 (below), so for
now each MCR-1 game is a baked bitstream.

Remaining before Phase A is closed:
- Flash + verify Kick and Solar Fox on hardware (video, sound, controls).
  Kick's spinner sensitivity and both games' DIP default (input_3 = 0xFF
  placeholder) will likely need tuning; OSD text rotation direction on the
  rotated MCR-1 monitors is a guess.
- Pack format v2 so MCR-1 games load from SD like MCR-2 (see below).

Original work items (mostly done):

1. **Diff the shared support files first** (`refs/Arcade-MCR1_MiSTer/rtl/`
   vs our `src/rtl/`): ours carry local fixes (dpram INIT_FILE ROM mode,
   mcr2 bg download decode). Take `mcr1.vhd`; keep ours for everything
   shared.
2. Vendor `mcr1.vhd` → `src/rtl/`. Its download map differs from MCR-2
   (verified): sprites `0x10000-0x17FFF`, bg1 `0x18000-0x18FFF`, bg2
   `0x19000-0x19FFF`; CPU ROM is 32 KB max, sound 16 KB.
3. `merge_roms.py`: add `kick`, `kickman`, `solarfox` specs (zips already
   in `roms/`), writing the MCR-1 layout; `make_rompack.py` gains a
   **pack format v2**: per-slot family byte + name, so one card serves
   every family bitstream and the loader refuses cross-family slots.
4. New `mcr1_console60k/` project = copy of the 60K project with the core
   swapped and a 2-game input mux (Kick: spinner on IP1 via `spinner.sv`,
   1 button; Solar Fox: stick + 2 buttons — bit maps from MAME mcr.cpp,
   recorded in `mcr_game_input_matrix.md` as we did for MCR-2).
5. OSD: game names come from the pack header (already written there by
   `make_rompack.py`) instead of hardcoded strings — after that, no
   family ever touches menu RTL again. Prefs record gains the family
   byte (sector format has room).

Deliverable: `bitstreams/console60k_mcr1.fs` — boots Kick, OSD switches
between the three, prefs persist. **This phase is deliberately first: it
forces all the multi-family packaging decisions while the RTL risk is
near zero.**

## Phase B — SDRAM module bring-up (the gate for all MCR-3)   [STARTED]

**Standalone memtest built (2026-07), not yet hardware-run.** The exact
controller MCR-3 will use is vendored and Gowin-adapted:
`src/rtl/sdram_gw.sv` = MiSTer MCR-3 `sdram.sv` with the Altera altddio_out
SDRAM_CLK forwarder replaced by a Gowin ODDR and the `inout reg SDRAM_DQ`
rewritten as an explicit tristate (Gowin rejects procedural drives of an
inout). A 100 MHz PLL (`gowin_pll_sdram.v`) feeds it (refresh timing sized
for ~100 MHz). `src/rtl/sdram_memtest.sv` sweeps 1M words (write pattern ->
read back -> compare) on port1; the diag top
`mcr2_console60k/diag/sdram_memtest_top.sv` reports on the four J10 LEDs
(PASS/DONE/FAIL/heartbeat) and the UART beacon. SDRAM pins from
`docs/pinrefs/snestang_console.cst` (verified nand2mario mapping, CS=F21).
Bitstream: `bitstreams/console60k_sdram_memtest.fs` (builds clean, timing
met at 100 MHz). FSM logic is Verilator-validated (`make -C sim memtest`:
clean memory PASSes, an injected bad word is caught at the right address).

**On hardware:** plug the Tang SDRAM module into J9, flash the memtest,
watch the LEDs. DONE+PASS = the module, pins and clock phase are good. If
reads fail (DONE+FAIL), the likely culprit is the SDRAM_CLK phase - swap
D0/D1 on the ODDR in `sdram_gw.sv` (the one documented phase knob) and
rebuild.

Remaining Phase B:
1. Run the memtest on real hardware; tune the clock phase if needed.
2. Retire the F19/F20 PMOD buttons (they overlap nothing here, but will
   when the module is wired into a real board build).
3. `rom_loader` v3: stream slots >128 KB through the `dl_` path into SDRAM
   (MiSTer's `rom_download` wiring in `Arcade-MCR3.sv` is the template).
   Pack v2 carries per-slot sizes.

## Phase C — MCR-3 core: Tapper, Timber, Journey, Discs of Tron

1. Vendor `mcr3.vhd`; SSIO is shared and already ours. Wire CPU/sound/
   sprite ROM ports to `sdram.sv` exactly as `Arcade-MCR3.sv` does
   (56 KB CPU, 16 KB sound, 128 KB sprites), bg via `dl_` into BRAM.
2. `wave_sound.sv` + samples in SDRAM for Journey's tape music (the
   MiSTer `/sound/journey.zip` sample pack becomes an extra pack-v2
   region streamed at boot). DoT ships without speech initially — same
   as MiSTer; real Squawk & Talk (6809 + TMS5200) is a separate stretch
   goal we can schedule if it stings.
3. Input maps per game from mcr.cpp (Tapper 2×2-way sticks + buttons;
   Timber 2 sticks; Journey stick+button; DoT stick + aim spinner on
   the Opt X bus — the shield's U3 '165 already carries it).
4. IP0 bit 4 is now "coin 3"-ish per game — re-verify all IP0 bits; the
   91490 games moved some system buttons.

Deliverable: `console60k_mcr3.fs`, 4 games, marquee titles done.

## Phase D — MCR3Scroll: Spy Hunter, Crater Raider, Turbo Tag

`mcr3scroll.vhd` + Cheap Squeak Deluxe (FX68K — new clocking to bring up,
one-time) + `steering_control.vhd` for wheel/pedal synthesis from pad or
real cabinet controls (shield '165 bus). Spy Hunter's lamp panel lands on
the shield's 74HC595 chain — add a second '595, zero header pins. CMOS
option: Crater Raider is SSIO-only if CSD proves stubborn — it can ship
from this core before Spy Hunter does.

## Phase E — MCR3Mono: Rampage, Sarge, Max RPM, Power Drive, Star Guards, Demolition Derby

`mcr3mono.vhd` + Turbo Cheap Squeak (`cpu09l`) + Sounds Good (FX68K,
already proven by Phase D). Rampage's 256 KB sprites are the biggest ROM
load of the whole family — SDRAM budget is fine, pack slots grow again.
Bonus once TCS exists: **Demolition Derby's 4-player version (`demoderb`)
is MCR-2 hardware + TCS** — it slots into our existing MCR-2 core.

## Cross-cutting decisions (do once, in Phase A)

- **Pack format v2**: version byte, per-slot {family, sector count,
  name}; loader rejects slots whose family byte doesn't match the
  running bitstream; OSD renders names from the header. Bigger slots
  (MCR-3: 512 KB; sample regions: MBs) are just sector counts.
- **Prefs v2**: add the family byte so the future multiboot selector
  (spec §7d) can pick the right *bitstream*, not just the right slot.
  Until multiboot exists, switching families = reflash (openFPGALoader
  one-liner, documented in README).
- **One board project per family** (`mcr1_console60k/` …): same top
  structure, different core + input mux. Shared fixes keep living in
  `src/`.
- **refs/ hygiene**: `refs/` is gitignored reference material (nested
  git checkouts). We copy files out deliberately, with a dated comment,
  as with every previous vendor (usb_hid_host, ddr3fb).

## Sequencing rationale

A before B because packaging decisions are cheaper to iterate on a
2-game BRAM core than on an SDRAM bring-up; B gates C/D/E; C first among
the MCR-3s because Tapper/DoT are the marquee titles and it needs no new
CPU cores (SSIO only); D before E so FX68K clocking is proven on one
board (CSD) before it appears twice more (Sounds Good).

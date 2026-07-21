# MCR family porting roadmap (Tang Console 60K)

Plan for bringing the remaining Bally Midway MCR generations onto the 60K,
in order of effort-to-payoff. Written 2026-07; supersedes the "Cores /
ports" sketch that used to live in TODO.md.

## What already carries over (the platform)

Everything below is core-agnostic and is reused by every phase unchanged:

- DDR3 framebuffer → 720p HDMI + audio; analog VGA at 31/15 kHz with sync
  straps; the OSD menu (core-raster overlay, so it works on every output);
  SD pack loader; USB HID pads; UART beacon; headless build flow.
- The SSIO sound board (`mcr_sound_board.vhd`) — MCR-1 and half of MCR-3
  use the *same* board the MCR-2 games do.
- T80/Z80CTC, `spinner.sv`, `dpram.sv`, the input-map conventions in
  `docs/mcr_game_input_matrix.md` (IP0..IP4 are identical across all
  SSIO-based generations — verified against MAME, see that doc).

Porting a family = new game-board core (video generator + memory map) plus
per-game input maps and ROM packing. It is **not** a new platform bring-up.

## Sources to vendor

Same dar/sorgelig lineage as our `mcr2.vhd`, so the code style and
structure will be familiar:

- MCR-1: <https://github.com/MiSTer-devel/Arcade-MCR1_MiSTer>
- MCR-3 (91490 + scroll games): <https://github.com/MiSTer-devel/Arcade-MCR3_MiSTer>
- MCR-3 monoboard: <https://github.com/MiSTer-devel/Arcade-MCR3Mono_MiSTer>

## ROM budget arithmetic (what forces SDRAM and when)

Anchor from the current build: 94/118 BSRAM *including* Tron's 108 KB of
ROM (54 blocks at 2 KB/block) → platform + core RAM ≈ 40 blocks →
**~78 blocks ≈ 156 KB of BSRAM available for game ROM**.

| Family | Game ROM totals | Verdict |
|---|---|---|
| MCR-1 (Kick, Solar Fox) | ~80 KB | BSRAM, easy fit |
| MCR-2 (current six) | 96–108 KB | BSRAM (shipping today) |
| 91490+SSIO (Tapper 232 KB, Timber, Journey; DoT 152 KB) | 152–232 KB | **SDRAM** (DoT alone is borderline-BSRAM) |
| MCR-3 scroll/mono (Spy Hunter, Crater, Rampage 480 KB, …) | 224–480 KB | **SDRAM**, plus second sound CPUs |

## Phase 1 — MCR-1 core: Kick, Kickman, Solar Fox  *(cheap win)*

The only genuinely new RTL is the 90009 video generator; sound is our
existing SSIO, ROMs fit BSRAM with lots of headroom, Kick's spinner is
`spinner.sv`. ROM zips are already in `roms/`.

Work items: vendor core → `src/rtl/mcr1.vhd`; a `mcr1_console60k` build
config (same top, new core + input maps); `merge_roms.py` gains the MCR-1
specs; pack format v2 (below); OSD menu shows the family's games.
Deliverable: `console60k_mcr1.fs` — boots Kick, OSD switches within family.

## Phase 2 — SDRAM bring-up  *(prerequisite for everything MCR-3)*

- Tang SDRAM module in the J9 slot. Chip select is **F21** on the Console
  (F19 on the Mega dock); F19/F20 are currently PMOD-button inputs —
  retire them, USB pads won.
- MiSTer's MCR3 cores already fetch ROMs from SDRAM (that is how MiSTer
  runs them) — port their arbitration rather than inventing one. We have
  a `src/rtl/sdram.sv` from the original port to start from.
- Extend `rom_loader.sv` to stream big pack slots into SDRAM instead of
  BSRAM (same download bus, bigger address space).

## Phase 3 — MCR-3 / 91490 + SSIO: Tapper, Timber, Journey

New 91490 video (same 512×480 scanner family, 4 bpp / 64 colors), SSIO
reused, ROMs from SDRAM. Journey's exact machine variant (background
board) to be confirmed against MAME during vendoring.

## Phase 4 — Squawk & Talk: Discs of Tron

M6809 + AY + TMS5200 speech, all present in the MiSTer MCR3 repo. DoT's
152 KB might even fit BSRAM, so this can land before Phase 2 if the
speech board turns out easy — treat the ordering of 2↔4 as flexible.

## Phase 5 — MCR-3 scroll + monoboard

- **Scroll video**: Spy Hunter (+ Chip Squeak Deluxe, a 68000 + DAC music
  board → `fx68k`), Crater Raider (SSIO), Turbo Tag (prototype).
- **Monoboard**: Sarge / Max RPM / Demolition Derby-mono (Turbo Cheap
  Squeak, 6809), Rampage / Power Drive / Star Guards (Sounds Good, 68000).
- Cabinet controls get interesting (wheel/pedals/dual sticks); lamps for
  Spy Hunter. Map to pads first, real cabinet I/O via the shield.
- Bonus unlocked by TCS: **Demolition Derby (`demoderb`, the 4-player
  version) is MCR-2 hardware + Turbo Cheap Squeak** — once TCS exists it
  slots into our *existing* MCR-2 core (verify machine config in mcr.cpp
  when we get there).

## Cross-cutting decisions

- **One bitstream per family.** Game switching *within* a family stays
  OSD + SD pack (proven). Switching *between* families = reflash for now
  (`openFPGALoader -b tangconsole -f bitstreams/<family>.fs`); a Gowin
  MultiBoot selector (all families fit the 8 MB flash) or the BL616/
  TangCore loader is its own later spike — decide when there are two
  families to switch between.
- **Pack format v2**: header gains a format version and per-slot family
  tag + sector count (128 KB slots for MCR-1/2, 512 KB for MCR-3);
  `make_rompack.py` already writes slot *names* into the header — the OSD
  should start rendering those instead of its hardcoded strings, so new
  families never touch the menu RTL.
- **Input maps**: extend `docs/mcr_game_input_matrix.md` per game as each
  family lands, from MAME, same as we did for the six MCR-2 titles.

## Order rationale

MCR-1 first because it is nearly free and forces the multi-family
packaging decisions (pack v2, OSD-from-header, per-family builds) while
the RTL risk is tiny. SDRAM second because it unlocks everything else.
Tapper is the marquee title and lands immediately after. Sound boards
last because each is a self-contained module with its own CPU core.

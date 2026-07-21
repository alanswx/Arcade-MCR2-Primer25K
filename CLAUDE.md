# CLAUDE.md

Bally Midway MCR2 arcade core (MiSTer/Cyclone V origin) ported to Sipeed Tang
Gowin FPGA boards as standalone, hardcoded builds (no HPS/ARM download bus —
ROMs are baked into BSRAM via `INIT_FILE` hex tables).

Current game: **Domino Man** (default). Satan's Hollow also supported (no
background tiles on the 25K — ROM budget). The 60K top carries the
MAME-verified Domino Man input map (Button 1 = IP0 bit 4, 4-way stick =
IP1[3:0], DIP IP3 = 0x3E for upright — 0xFF means cocktail!); the 25K top
still has the Satan's Hollow map.

## Board projects

| Dir | Board | FPGA | Status |
|---|---|---|---|
| `mcr2_primer25k/` | Tang Primer 25K | GW5A-LV25MG121 | **Working** — Domino Man attract mode over HDMI, 56/56 BSRAM, timing met |
| `mcr2_console60k/` | Tang Console 60K | GW5AT-LV60PG484 | **Working** — USB HID gamepad; all six games compiled in, OSD menu (Select+Start) switches at runtime via the SD pack; DDR3 framebuffer → 720p HDMI w/ audio; analog VGA on J10 with 15/31 kHz strap |
| `mcr2_console138k/` | Tang Console 138K | GW5AST-LV138 | Stale pre-fix top; needs same backport as 60K |

Shared, platform-independent code lives in `src/`:
- `src/rtl/` — MCR2 core (`mcr2.vhd`), T80 Z80, Z80CTC, PLL (`gowin_pll_mcr2.v`), RAM wrappers (`dpram.sv`)
- `src/dvi_tx/` — TMDS encoder + OSER10-based HDMI serializer
- `src/audio/` — delta-sigma PWM DAC
- `src/usb/` — nand2mario `usb_hid_host` (MIT, vendored 2026-07) + 12 MHz
  PLLA (`gowin_pll_usb.v`). Keep `usb_hid_host_rom.hex` next to its `.v` —
  `$readmemh`/`INIT_FILE` resolve relative to the source file's directory.
- `src/ddr3fb/` — nand2mario/gbatang DDR3 framebuffer (vendored 2026-07,
  GPLv3 — see LICENSE.gbatang): `ddr3_framebuffer.v` + Gowin DDR3 IP +
  27 MHz/DDR3/HDMI PLLAs + hdl-util HDMI stack with audio. Used by the 60K
  only (`dvi_tx/` remains the 25K's HDMI path).
- Each board dir has only: `.gprj`, `build.tcl`, `src/<board>_top.sv`, `.cst`, `.sdc`

Because the PLL and `mcr2.vhd` are shared, fixes there apply to every board
automatically; the per-board top/SDC/CST must be kept in sync by hand (the 25K
top is the reference implementation).

## Build (headless, macOS)

GowinIDE bundles Tcl; the CLI needs dylib/framework paths set (`$ORIGIN`
doesn't resolve on macOS):

```sh
GWLIB=/Applications/GowinIDE.app/Contents/Resources/Gowin_EDA/IDE/lib
GW=/Applications/GowinIDE.app/Contents/Resources/Gowin_EDA/IDE/bin/gw_sh
cd mcr2_primer25k        # or mcr2_console60k
DYLD_LIBRARY_PATH="$GWLIB" DYLD_FRAMEWORK_PATH="$GWLIB" "$GW" build.tcl
```

Bitstream lands at `<board>/impl/pnr/<board>.fs`. Flash with Gowin Programmer
(GUI) or `openFPGALoader`. To make a build the POWER-ON default (survives
power cycles, replaces whatever is in the SPI flash - e.g. NESTang):
`openFPGALoader -b tangconsole -f bitstreams/console60k_<game>.fs`.
For a volatile test load (SRAM only, lost at power-off) drop the `-f`.

### Post-build sanity checks (do these every build)
1. **No `PA1019`** (PLL VCO out of range) warning in the log — with ONE
   accepted exception on the 60K: `gowin_pll_hdmi` (27 MHz x 55 = 1485 MHz
   VCO for 720p TMDS) always warns. That is NESTang's standard config,
   confirmed working on this hardware; a PA1019 naming any OTHER PLL
   (especially `gowin_pll_mcr2`) is still a build-breaker.
2. 25K only: `BSRAM ... 56/56` in `impl/pnr/*.rpt.txt` — must not exceed 56.
3. Positive SETUP and HOLD slack in `impl/pnr/*.timing_paths`.
4. **`grep -i "Undeclared symbol" impl/gwsynthesis/*.log` must be empty.**
   Gowin turns use-before-declaration into an implicit **1-bit wire** with
   only a warning. A multi-bit signal referenced above its declaration
   becomes one floating bit — this produced a perfectly synced, entirely
   black HDMI picture (rgb input dead, its FIFO swept as unused) while the
   build reported zero errors. Declare before use, always.

## ROMs

MAME ROM zips live in `roms/` — **gitignored, so a fresh clone has none**;
copy them in by hand on each machine (the script now aborts with exit 1 and
leaves `game_config.vh` alone if the zip is missing, rather than producing a
half-switched build). Generate the hex tables from the **repo root**:

```sh
python3 tools/merge_roms.py domino    # default
python3 tools/merge_roms.py tron
python3 tools/merge_roms.py shollow
```

Writes `rom_*.hex` into every board's `src/` and into `src/rtl/`, **and**
generates `game_config.vh` in the console board dirs. On the 60K all six
per-game input/DIP maps are compiled in and muxed at runtime by `game_id`
(owned by the OSD menu in `src/rtl/osd.sv`); `game_config.vh` (`GAME_TRON`
etc.) only sets which game's ROMs are BAKED in — i.e. what boots with no SD
card — and the matching `GAME_DEFAULT` for `game_id`. ROMs and input map
still always match: at boot both come from the script's game, and an OSD
switch reloads ROMs from the SD pack as it changes `game_id`. Gowin resolves `INIT_FILE`/`include` relative to the
**instantiating source file's directory**: the board tops (`rom_main.hex`,
`rom_snd.hex`, `game_config.vh`) resolve next to themselves; the gfx ROMs
instantiated inside `mcr2.vhd` (`rom_gfx1_*.hex`, `rom_gfx2.hex`) resolve
against `src/rtl/`. That's why the script writes to multiple dirs.
(`src/roms/*.hex` is a stale Satan's Hollow set from the initial port — do
not point new code at it.)

Prebuilt flashable images are kept in `bitstreams/` (e.g.
`console60k_tron.fs`, `console60k_domino.fs`) so switching games on the
board is just a reflash, no rebuild. Regenerate them after RTL changes.

Per-game notes (bit maps verified against MAME `mcr.cpp`):
- **Domino Man** — 4-way stick (IP1), Button 1 = IP0 bit 4, DIPs 0x3E.
- **Tron** — 8-way stick on **IP2**, aim dial (absolute 8-bit spinner) on
  IP1 via `spinner.sv` (pad X/Y rotate; `spin_in` reserved for a USB mouse),
  trigger = IP0 bit 4, DIPs 0x80. MAME marks the dial PORT_REVERSE — if aim
  feels inverted, swap the spinner's minus/plus hookup.
- **Satan's Hollow** — fire/shield/right/left on IP1 low nibble, DIPs 0xFF.
- **Wacko** — trackball X/Y on IP1/IP2 (two `spinner.sv` instances driven by
  the d-pad); aim joystick on the face buttons via IP4.
- **Kozmik Kroozr** — spinner bits packed into IP1 (bit6=dial[7],
  bits2:0=dial[6:4], active **high**); analogue stick synthesised on
  IP2/IP4 (ramps toward 0x30/0x98, recentres to 0x64 on release).
- **Two Tigers** — the `twotigerc` conversion set; dial on IP1, fire
  buttons on IP2[3:0]. The dedicated set needs a videoram remap we lack.

All six MCR-2 games fit the same core: `merge_roms.py` has ROM specs for
each and `make_rompack.py` packs them into one card image.

## Hard-won constraints — do not regress these

### PLL (`src/rtl/gowin_pll_mcr2.v`)
GW5A PLLA VCO **must stay within 700–1400 MHz**. Current config: 50 MHz in,
MDIV 20 → VCO 1000 MHz; ODIV0 8 → `clk_p5` 125 MHz (TMDS 5× bit clock);
ODIV1 25 → `clk_sys` 40 MHz (core). `clk_pixel` = 25 MHz via `CLKDIV`
DIV_MODE=5. A 1500 MHz VCO was the root cause of the original "rolling screen"
(every derived clock silently wrong, core at ~75 MHz).

### SDC (per board)
The `create_generated_clock` lines for `clk_sys`/`clk_pixel` and the
`set_clock_groups -asynchronous` between them are **required**. Without them
the pixel domain falls back to a 100 MHz default and reports false setup
violations. Do not remove; instance names (`pll_inst/PLLA_inst/CLKOUT1`,
`clk_div_inst/CLKOUT`) must match the top.

### HDMI video — 60K: DDR3 framebuffer (current)
**Two structural rules, both learned the hard way:**
1. **`clk_g` (50 MHz DDR3-controller/mDRP clock) MUST come from a PLL
   output, not the raw clock pad** — pad-fed clk_g put a derived controller
   clock on generic routing (PR1014) and the DDR3 IP never started.
2. **The TMDS serializer clocks MUST be one chain**: 27 MHz → gowin_pll_hdmi
   → 371.25 MHz → CLKDIV÷5 → 74.25 MHz (NESTang's arrangement). Upstream
   gbatang clocks the hdmi module from the DDR3 controller's `clk_x1` and
   the serializer from a second PLL — the OSER10 PCLK/FCLK phase is then
   routing luck, and it produced synced-but-dead TMDS here even in a
   minimal design. The scanout still runs on `clk_x1`; pixels cross into
   `hclk` via a shadow raster (720p counters re-aligned each frame, running
   32 px ahead) into a 64-deep async FIFO — drift-free because both clocks
   descend from the same 27 MHz.

The 60K top streams the core's native pixels (512×480, RGB444, one `fb_we`
per 20 MHz pixel, `cap_delay` capture-window shift — live-tunable with
Select+D-pad, current value in the UART beacon as `dXX`) into
`ddr3_framebuffer` (gbatang), which upscales to 1280×720@60 HDMI with audio
— fully decoupled from core timing: no shimmer, no genlock, and HDMI stays
alive in 15 kHz mode (capture height switches to 240). `disp_width=960`
gives 4:3. The framebuffer generates its own 297 MHz DDR3 + 74.25/371.25 MHz
HDMI clocks from a 27 MHz PLLA; the SDC declares `clk4x`/`clk1x` on
`fb_inst/` nets and cuts them from `clk_sys` (the internal async FIFO is the
crossing). Costs ~15 BSRAM + ~3.5k LUT; 5/8 PLLAs used.

### HDMI video pipeline — 25K only (legacy line-buffer approach)
The core natively emits 634×525 @ 20 MHz (512×480 active, 31.5 kHz/60.09 Hz)
in `tv15Khz_mode=0`. The 25K conforms it to 640×480@~60 via a 2-line
ping-pong buffer (clk_sys → clk_pixel). Three deliberate oddities:
- **`H_TOTAL = 793`** (not 800): matches output line rate to the core within
  0.06%, minimizing mid-line buffer switches (shimmer). Don't "fix" to 800.
- **Vertical genlock**: output vcnt restarts on core vblank falling edge —
  prevents slow vertical roll from the residual rate mismatch.
- **`CAP_DELAY = 13`**: compensates the core's RGB-vs-hcnt pipeline lag.
  Tuning: sliver on left edge → increase; on right edge → decrease.

Residual faint shimmer is a known limit of the line-buffer approach on the
25K (no room for a frame buffer there).

### BSRAM budget (25K)
56 blocks total. Domino Man fits exactly (CPU 16 + sound 8 + bg 2×4 + sprites
16 + core RAM/line buffer ~8). Satan's Hollow's 48 KB CPU ROM forces dropping
the bg tile ROMs. `dpram` in ROM mode reads only port A; the `dl_*` download
bus is inert in these standalone builds.

### Buttons / diagnostics
25K: S1 = reset, S2 = color-bar test pattern + Coin 1.
60K: key AA13 = reset, key AB13 = Coin 1. **Select+Start opens the OSD
game-select menu** (Up/Down move, A loads the highlighted game from the SD
pack, B exits; all game inputs are masked while it is open; the raster
stops during the ~1 s reload, so the screen freezes/drops sync — expected).
The menu draws in the core raster domain, so it appears on HDMI and analog
video alike, rotated on Tron/Shollow (ROT90 cabinets). UART beacon on U15
(→ USB-C serial, 115200): `FB c<calib> r<ddr_rst> x<clk_x1 cnt> q<27M cnt>
d<aux>` every ~0.5 s, where `d`'s high 3 bits = running `game_id` and low
5 bits = cap_delay — frozen counters identify a dead clock domain with the
case closed. Select+D-pad Right/Left tunes the capture delay live (D-pad is
masked from the game while Select is held).

### Analog video (60K): PmodVGA on J10
`vga_r/g/b[3:0]` (3:3:3 core color MSB-replicated to 4:4:4) + `vga_hs/vs`,
jumper-wired per the recipe in `mcr2_console60k.cst`. `mode15_n` strap
(J10-37): open = 31 kHz progressive; GND = native 15 kHz (HS pin carries
csync, HDMI intentionally falls back to color bars because the line-buffer
scaler can't track 15 kHz timing). The J10/SDRAM1 balls overlap CPU/SSPI
config pins → `build.tcl` needs the `-use_*_as_gpio` option block (already
there; the IDE JSON equivalents are the CPU/MSPI/SSPI/etc. booleans).

## Docs map

- `docs/bench_wiring.md` — **what the current bitstream drives on J10**
  (VGA, straps, debug pins, audio) for temporary bench hookups. Wire from
  this, not from the shield spec's §4b cabinet plan.
- `TODO.md` — **open issues and known gaps, consolidated**. Check (and
  update) this before starting anything; per-doc "open items" sections feed
  into it.

- `handoff_v3_video_and_domino.md` — **most current**: video pipeline
  deep-dive, Domino POC, ROM-fit table for all MCR games, paths forward.
- `handoff_v2_design.md` — SDRAM/V2 plan, shield electrical spec, MCR
  J2/J3/J4/J5 connector pinouts.
- `board_comparison_and_bom.md` — board comparison + shield BOM.
- `pcb_design.md` — Universal MCR shield PCB spec; generator at
  `tools/generate_pcb.py` (run with KiCad's bundled python) →
  `mcr_shield.kicad_pcb`.
- `docs/universal_mcr_shield_spec.md` — **consolidated shield spec** (net
  table, electrical, pin budget); supersedes the electrical sections of the
  two docs above for new work.
- `docs/mcr_game_input_matrix.md` — machine-readable transcription of the
  pinout matrix PDF + MAME-verified SSIO bit maps; use it when porting a
  new game.
- `docs/MCR_Master_Pinouts.pdf` — master MCR cabinet pinout matrix (the
  original source for the two docs above). Confirms per-game J2/J3/
  J4/J5 usage; e.g. Domino Man = 4-way joystick + 1 button ("Place/Strike").
- `docs/pinrefs/` — known-good Tang Console 60K / Mega 60K constraint files
  fetched from nand2mario's nestang/snestang/gbatang and Sipeed's NEO_DOCK
  examples; the authority for 60K pin questions (USB, SD, SDRAM, DDR3,
  PMODs, UART).
- `docs/Tang_Mega_60K_Console_32001{A,C}__Schematics.pdf` — official dock
  schematics (rev A and C). Sheet 4/6 = SOM connector ball maps, sheet 8 =
  the two 2×20 headers (J9 "SDRAM0" near PCIe, J10 "SDRAM1"/GBA near
  PMODs). J10's full pin↔ball table is transcribed in
  `universal_mcr_shield_spec.md` §4a.
- `README.md` / `walkthrough.md` — overview + GUI build steps (partly stale:
  written before the 60K/138K backlog was known).

## Gotchas

- **The IDE and `build.tcl` are separate config paths, and the IDE rewrites
  its JSON with GUI defaults on save** — settings put there by hand get
  clobbered. Everything `build.tcl` sets must be mirrored in
  `impl/<project>_process_config.json` for IDE builds:
  | build.tcl | JSON key | symptom if wrong |
  |---|---|---|
  | `-top_module` | `TopModule` | synthesis picks `T80pa`; PnR error PA2024 |
  | `-verilog_std sysv2017` | `Verilog_Standard` = **`"Vlg_Std_Sysv2017"`** (exact token; an invalid value silently falls back to Verilog-2001) | `.sv` parsed as Verilog-2001: "single value range not allowed" (usb_hid_host.v:42), or "Instantiating unknown module 'uart_beacon'" because its ANSI port initializer won't parse |
  | `-place_option 2` | `Place_Option` = `"2"` | **CONFIRMED on hardware: `"0"` (the IDE default) yields a bitstream that builds clean and meets timing but whose DDR3 never trains → HDMI stays black.** Always 2 for this design. |
  | `-use_cpu_as_gpio` etc. | `CPU`,`MSPI`,`SSPI`,`READY`,`DONE`,`I2C` = true | "location is a dedicated pin (CPU)" on J10/`vga_*` pins (GUI: Place & Route → Dual-Purpose Pin) |
  Never set `JTAG` true — that removes the programming interface.
  **The headless `build.tcl` flow is immune to all of this** and is the
  recommended path on any machine (`gw_sh build.tcl` from the board dir).

  Also: **`gw_sh` rewrites this JSON after a build and does NOT persist
  `place_option` / `rw_check_on_ram` / `multi_boot`** — it writes their
  defaults back regardless of what build.tcl passed. So the file is not a
  record of how a CLI build was made (build.tcl is), it churns in `git
  status` after every build, and its values matter *only* to IDE builds.
  If you build in the IDE, verify **Place & Route → Place Option = 2**
  yourself; that one silently costs you all HDMI output.
- **Bank 9 is a 1.5 V bank on the 60K once DDR3 is used** (the DDR3 data
  group lives there). Anything on Bank 9 balls (user keys AA13/AB13, Y12,
  Y13, Y14, W11…) must be `IO_TYPE=LVCMOS15 BANK_VCCIO=1.5` — LVCMOS33
  there fails PnR with CT1136 bank conflicts.
- Tang Console 60K quirks: user keys are **active low** (the 60K top inverts
  them; the 25K's are active high), clock is 50 MHz on V22, and
  `-device_version B` is required. The USB-A D+/D− lines land on FPGA pins
  (usb1: H13/G13, usb2: M15/M16) with the 15 kΩ host pulldowns already on the
  board — ready for nand2mario's `usb_hid_host`. Tang SDRAM module chip
  select is F21 on the Console (F19 on the Mega 60K dock), and F19/F20 are
  currently used as PMOD1 button inputs — reassign if the SDRAM module goes in.
- Cabinet video/audio pins in the 60K CST are marked PROVISIONAL — re-verify
  header positions against the Sipeed schematic before wiring a shield.
- The 138K project top/SDC are still the pre-fix architecture (direct
  core→HDMI, no line buffer). Port from the 60K top when needed.
- `impl/` outputs are committed in this repo; expect large binary diffs after
  builds.
- Working-tree changes are often intentionally uncommitted during bring-up;
  check `git status` before assuming HEAD reflects the working design.

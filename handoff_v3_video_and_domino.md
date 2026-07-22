# MCR Port V3 Handoff — HDMI Video Bring-up & Domino Man POC

> **Historical.** This documents the Tang Primer 25K HDMI bring-up and the
> Domino Man proof-of-concept. Every "path forward" it lists (SDRAM
> framebuffer, USB, bigger boards) is now done on the 60K. For the current
> state see **`handoff_v4_60k_multicore.md`**.

Status as of this session. Covers the working Tang Primer 25K build, the video
pipeline and its known limits, the Domino Man proof-of-concept (background tiles
enabled), the MCR ROM-fit analysis, and the recommended paths forward.

---

## 1. Current state (Tang Primer 25K)

- **Domino Man (MCR2) runs with full background + sprites over HDMI.** Renders
  correctly; boots to attract mode. Fits **56/56 BSRAM**, timing met
  (setup +0.48 ns, hold +0.27 ns).
- Bitstream: `mcr2_primer25k/impl/pnr/mcr2_primer25k.fs`.
- Two video outputs are generated simultaneously: **HDMI** (TMDS) and the core's
  native **analog RGBS** (`cab_*` pins, currently unused but wired).
- Known residual: slight **shimmer** on HDMI (see §4). Left-edge overlap is fixed.

### The original problem (solved)
The screen was "rolling." Root cause was **not** the video logic — it was a
broken PLL: the GW5A VCO was set to 1500 MHz, outside the valid 700–1400 MHz
window, so every derived clock was wrong (core ran at ~75 MHz and failed timing;
refresh was a non-standard ~60.6 Hz). Fixing the PLL fixed the rolling.

---

## 2. Clock configuration (the critical fix)

`src/rtl/gowin_pll_mcr2.v` — VCO **must** stay in 700–1400 MHz.

| Param | Value | Result |
|---|---|---|
| FCLKIN | 50 MHz | input |
| IDIV_SEL / FBDIV_SEL | 1 / 1 | — |
| MDIV_SEL | **20** | VCO = 50·1·20/1 = **1000 MHz** (valid) |
| ODIV0_SEL | **8** | `clk_p5` = 1000/8 = **125 MHz** |
| ODIV1_SEL | **25** | `clk_sys` = 1000/25 = **40 MHz** (core) |

`clk_pixel` = `clk_p5` / 5 = **25 MHz** via `CLKDIV DIV_MODE="5"`.
`clk_p5` (125 MHz) is the 5× TMDS bit clock feeding the OSER10 serializers.

**SDC (`mcr2_primer25k/src/mcr2_primer25k.sdc`):** the CLKDIV output and the core
clock must be declared explicitly (the tool's auto "default_gen_clk" names are
not queryable at parse time), and the core↔pixel line-buffer crossing is marked
asynchronous — otherwise you get false setup violations. Do not remove these.

---

## 3. HDMI video pipeline (`mcr2_primer25k_top.sv`)

The MCR core (31 kHz mode, `tv15Khz_mode=0`) natively emits **634×525 @ 20 MHz,
512×480 active, negative H/V sync, 31.5 kHz / 60.09 Hz**. We conform that to a
standard **640×480@~60 (VGA/DMT)** HDMI mode and center the game:

- **Sync generator:** 640 active + 16 FP + 96 sync + 41 BP = **793 H total**
  (see below), 525 V total, negative H/V sync, DE gated.
- **Centering:** 512-wide game in 640 active → 64 px left margin (margins black).
- **Clock-domain crossing:** a **2-line ping-pong buffer** (`line_buffer`,
  1024×9, 1 BSRAM block). Core writes at `clk_sys`; HDMI reads at `clk_pixel`.
  Read selects the buffer not currently being written (`read_buffer_idx`).

Three tuning fixes are layered on top, each addressing a specific artifact:

1. **`H_TOTAL = 793`** (not the standard 800). The core emits one line per
   634 core-pixels @ 20 MHz; 634·(25/20) = 792.5, so 793 output pixels @ 25 MHz
   makes the output line rate track the core to within 0.06% (vs 0.94% at 800).
   This nearly stops mid-line buffer switches → **big reduction in shimmer/tear.**
2. **Vertical genlock.** The output vertical counter restarts at each core frame
   (falling edge of core `vblank`), so the ~0.5 Hz frame-rate mismatch can't
   accumulate into a slow vertical roll. H is never disturbed (HSync stays clean).
   Bypassed in test-pattern mode (S2).
3. **`CAP_DELAY = 13`** — the core's RGB output lags its `hcnt` by a fixed
   pipeline delay (tile fetch → gfx ROM → palette → output regs). Indexing the
   buffer by raw `hcnt` captured the *previous* line's tail into the first ~13
   entries → a garbled strip on the left edge. The write index is shifted back by
   `CAP_DELAY` and capture runs a few pixels into hblank to keep the drained
   pixels. **Tunable:** sliver on the left → increase; sliver on the right →
   decrease.

**Diagnostics:** S2 button (pin H10) toggles a free-running 640×480 color-bar
test pattern (standalone, not genlocked) — good for confirming the monitor locks
independent of the core.

---

## 4. Known limitation: residual HDMI shimmer

The 2-line ping-pong buffer bridges two clocks that are *close* but not locked.
The three fixes above make it good, not perfect — expect a faint seam to drift
through roughly once per frame on detailed content.

**This cannot be fully fixed on the 25K over HDMI.** The clean solutions are:
- **Don't buffer at all** → analog VGA out (see §6, recommended easy win), or
- **Full-frame buffer** (the NESTang approach) → needs memory the 25K lacks.

For reference, NESTang's `nes2hdmi.sv` keeps the entire NES frame (256×240×6bit
≈ 46 KB) in dual-port BRAM and scans HDMI out of the *completed* frame — zero
tearing. Our MCR2 frame (512×480) is ~180 KB as palette-index / ~270 KB as RGB;
the GW5A-25 has ~126 KB BRAM total and we're at 56/56, so a full-frame buffer
does not fit here. It fits trivially on the 60K/138K.

---

## 5. Domino Man POC — how it was done

Domino Man was chosen because its **32 KB CPU ROM** (vs Satan's Hollow's 48 KB)
frees exactly the 8 BSRAM blocks the background tile ROMs need.

| ROM | Size | BSRAM blocks |
|---|---|---|
| CPU | 32 KB | 16 |
| Sound | 16 KB | 8 |
| BG plane 1 (gfx1_1) | 8 KB | 4 |
| BG plane 2 (gfx1_2) | 8 KB | 4 |
| Sprites (gfx2) | 32 KB | 16 |
| + core RAMs / line buffer | — | ~8 |
| **Total** | | **56 / 56** |

Changes made:
1. **`tools/merge_roms.py`** — refactored to a shared `build()` with a game
   selector. Run `python3 tools/merge_roms.py domino` (default) or `... shollow`
   from the **repo root**. Writes `rom_*.hex` into both `mcr2_primer25k/src/` and
   `src/rtl/`.
2. **`src/rtl/mcr2.vhd`** (~line 766) — re-enabled the two `bg_graphics` tile
   ROMs (8 KB each, addressed by `bg_code_line`, `INIT_FILE` = `rom_gfx1_1.hex` /
   `rom_gfx1_2.hex`), mirroring the existing `sprite_graphics` instantiation.
   Note: the `dpram` in ROM mode only reads on port A; the download port is inert
   (the Primer build loads via `INIT_FILE`, not the `dl_*` download bus).

**Not yet done for Domino Man:** input map still reflects Satan's Hollow
(`mcr2_primer25k_top.sv`, `input_0`/`input_1`). Boots to attract and shows
graphics, but in-game controls/DIPs need remapping for correct play.

---

## 6. Recommended paths forward

### A. VGA PMOD (analog) — cleanest image on the 25K, least effort
The core's native video is already wired to analog RGBS (`cab_r/g/b`, `cab_hs`,
`cab_vs`, `cab_csync`) in the CST. A VGA PMOD (resistor-DAC on RGB + HS/VS) driven
from these pins outputs the core's **native timing directly** — no buffer, no
clock crossing → **no shimmer/tearing/seam.** Analog monitors lock to whatever
H/V you send, so they're far more forgiving than HDMI.
- **31 kHz** (current `tv15Khz_mode=0`): works on a standard VGA monitor.
- **15 kHz** (`tv15Khz_mode=1`): authentic arcade signal — needs an arcade/
  multisync CRT or a scan converter (OSSC/RetroTink); a normal VGA LCD won't sync.
- Uses only ~11–14 pins (one PMOD header), leaving the other header for controls.
- **TODO when the PMOD arrives:** remap `cab_*` in the CST to the PMOD's pinout;
  optionally add an S-button toggle for 15/31 kHz.

### B. USB game controller
FPGA has no built-in USB host. Easiest route: soft **USB-HID host core**
(nand2mario `usb_hid_host`, built for Tang) on two GPIO wired to the USB D+/D−,
decoding a **DInput/standard-HID** pad (avoid XInput/Xbox) into `input_0/1`.
Prerequisite: confirm the USB-A data lines land on **FPGA pins** (not the debug
MCU). The **Tang Console 60K** is believed to have this wired already; confirm
D+/D− routing from the schematic. Minimal added hardware on the 25K: USB-A
breakout + 2×15 kΩ pull-downs + 5 V to VBUS.

### C. SDRAM framebuffer — the "do it right" HDMI path
The received SDRAM board enables a NESTang-style full-frame buffer (clean HDMI)
and can also hold ROMs (freeing BRAM). **Caveat (confirmed concern):** SDRAM eats
~30–40 pins, squeezing control inputs on the 25K's ~60 usable GPIO. Best deferred
to the **60K/138K**, where SDRAM/DDR is onboard on **dedicated pins** (costs zero
GPIO). See `handoff_v2_design.md` for the SDRAM controller + boot-loader plan.

### D. Bigger boards (60K/138K) — the target build
Far more BRAM + onboard DDR. Do it the NESTang way: full 512×480 frame buffer →
720p output (no shimmer/tear/seam), USB controllers, all games fit (including the
big MCR3 titles). The console ports exist (`mcr2_console60k`, `mcr2_console138k`)
but currently only replicate the primer's pin set (no USB/SDRAM wired yet).

---

## 7. MCR ROM-fit analysis (25K, ~48 blocks for ROM after RAM overhead)

| Game | Family | Total ROM | Fit w/ background? | Core work |
|---|---|---:|:--:|---|
| Kick | MCR1 | 80 KB | ✅ (headroom) | new core (shares video + SSIO) |
| Solar Fox | MCR1 | 80 KB | ✅ (headroom) | new core (shares video + SSIO) |
| **Domino Man** | MCR2 | 96 KB | ✅ (exact 56/56) | **none — running now** |
| Satan's Hollow | MCR2 | 108 KB | ❌ (bg cut) | none |
| Tron | MCR2 | 108 KB | ❌ | none |
| Discs of Tron | MCR3 | 152 KB | ❌ | new core |
| Crater Raider | MCR2 | 220 KB | ❌❌ | none |
| Tapper | MCR3 | 232 KB | ❌❌ (128 KB sprites) | new core |
| Demolition Derby | MCR3 | 224 KB | ❌❌ | new core + dual-CPU |
| Rampage | MCR3 | 480 KB | ❌❌❌ | new core |

Takeaways: **MCR1 (Kick/Solar Fox) is the smallest family** and the natural next
small port. **MCR3 is the wrong direction** for the 25K (bigger, some dual-CPU) —
save for the big boards.

---

## 8. Build & flash

Headless build on macOS (GowinIDE bundles Tcl; the CLI needs the dylib +
framework paths set, and `$ORIGIN` doesn't resolve on macOS):

```sh
GWLIB=/Applications/GowinIDE.app/Contents/Resources/Gowin_EDA/IDE/lib
GW=/Applications/GowinIDE.app/Contents/Resources/Gowin_EDA/IDE/bin/gw_sh
cd mcr2_primer25k
DYLD_LIBRARY_PATH="$GWLIB" DYLD_FRAMEWORK_PATH="$GWLIB" "$GW" build.tcl
```

To switch games: `python3 tools/merge_roms.py <domino|shollow>` from the repo
root, then rebuild. Bitstream lands at `mcr2_primer25k/impl/pnr/mcr2_primer25k.fs`.

Sanity checks after a build:
- No `PA1019` (VCO range) warning in the log.
- `BSRAM ... | 56/56` in `impl/pnr/mcr2_primer25k.rpt.txt` (must not exceed 56).
- Positive SETUP/HOLD slack in `impl/pnr/mcr2_primer25k.timing_paths`.

---

## 9. Key files & tuning knobs

| File | Purpose |
|---|---|
| `mcr2_primer25k/src/mcr2_primer25k_top.sv` | top: clocks, line-buffer scaler, sync gen, inputs |
| `src/rtl/gowin_pll_mcr2.v` | PLL (VCO/dividers) |
| `src/rtl/mcr2.vhd` | MCR2 core (bg ROMs re-enabled ~L766) |
| `mcr2_primer25k/src/mcr2_primer25k.sdc` | generated-clock + async-group constraints |
| `mcr2_primer25k/src/mcr2_primer25k.cst` | pin map (incl. unused `cab_*` analog RGBS) |
| `tools/merge_roms.py` | build `rom_*.hex` per game |
| `mcr2_primer25k/build.tcl` | Gowin build script |

**Tuning knobs in `mcr2_primer25k_top.sv`:**
- `H_TOTAL` (793) — output line rate vs core line rate (shimmer).
- `CAP_DELAY` (13) — left/right-edge pixel alignment.
- Genlock uses core `vblank`; test pattern on S2 (`reset2`).

# Handoff v5 — MCR-3 (Tapper) SDRAM sprite bring-up

**Status: Tapper renders on the 60K (background + CPU + OSD + audio), but
sprites show as SOLID WHITE BOXES.** Two real bugs already found and fixed; a
third fault remains. A diagnostic build is flashed to pinpoint it, but the
UART beacon is wedged — read it after the reboot. Start here.

This supersedes `handoff_v4_60k_multicore.md` for the MCR-3 sprite work; v4 is
still the reference for the broader 60K multi-core platform.

---

## TL;DR — where we are

- **Increment 0 (done, on hardware):** the MCR-3 core (`mcr3.vhd`, Tapper)
  boots and runs on the 60K platform — background tiles, CPU, sound, OSD
  (Select+Start), coin/start all work. Sprites were tied off (blank). Input
  mux corrected vs MAME/MiSTer. Commits `4b1179e`, `ce7a47e`.
- **Phase 1 (in progress):** move the 128 KB sprite ROM into the Tang SDRAM
  module (J9) and stream it from SD at boot. Builds clean (BSRAM 88/118,
  setup +1.7–1.9 ns). Commits `00f7088`, `957fb8f`, `4d82a8f`, plus the
  temporary diagnostic `HEAD`.
- **The remaining fault:** the core reads the sprite pattern word `sp_q` back
  from SDRAM as **constant all-ones (0xFFFFFFFF)** → every sprite is a solid
  white rectangle. No variation at all.

## Decisions locked this session (do not relitigate)

1. **Sequencing: sprites-first, then all-SD.** Phase 1 = SDRAM sprite path
   with CPU/sound/bg still baked in BSRAM. Phase 2 = empty the BSRAM and load
   *everything* from SD (the ship-with-no-ROMs goal). Phase 3 = back-port to
   MCR-1/MCR-2.
2. **Ship with no baked ROMs** (legal posture: we don't distribute WB/Midway
   IP; the owner supplies ROMs on SD — the standard MiSTer/Analogue model).
   This is *why* Phase 2 exists.
3. **Adopt the MiSTer `.mra` as the ROM-assembly spec — later**, wired into
   our Python pipeline (no external C tool; we already read the zips). It
   gives part order + DIP defaults for every game. NOT needed for Phase 1: the
   sprite *interleave is hardware* (the SDRAM write-swizzle), not in the `.mra`.

---

## THE ACTIVE BUG — solid white sprite boxes

**Symptom:** sprites render as solid white rectangles at the correct positions
and sizes. Position/size come from the core's sprite RAM (BSRAM, working). The
solid-white fill means the *pattern* word `sp_q` reads as all-ones for every
fetch. "No variation" ⇒ `sp_q` is *constant* all-ones, never real data.

**Already fixed (both real, both committed in `957fb8f`):**
1. **Wrong bank group.** The SD→SDRAM sprite *write* went to `sdram_gw`
   **port1** (controller bank 0/1), but the core's sprite *read* uses the
   **sp** port (bank 2/3). Different physical banks ⇒ reads never saw the
   writes. Fixed: write now uses **port2**, which shares the sp read's bank 2/3
   group (this is exactly why MiSTer's Arcade-MCR3 uses port2). port1 tied off.
2. **`port2_we` typo in `sdram_gw.sv`.** The bank-2/3 `PORT_REQ` path gated its
   write-enable on `port1_we` (copy-paste from the bank-0/1 block) — every
   port2 write silently decoded as a read. Never caught because the memtest
   only drove port1. Fixed to `port2_we`.

**Still white after both fixes.** So `sp_q` is *still* constant all-ones.

### Diagnostic build (flashed to SPI flash, = current `HEAD`)
Temporary beacon instrumentation added (`mcr3_console60k_top.sv`, commit
`HEAD` — revert once solved). The beacon `FB ...` line now means:

- **`x` = `spw_count[23:8]`** — number of sprite writes *issued* to SDRAM.
  After a full 128 KB load expect **`x ≈ 0x0200`** (131072 >> 8). **`x0000`
  = the writes are not happening at all.**
- **`q` = `spw_count[7:0]`** — low bits (extra resolution while loading).
- **`L` bit 7 = `spq_nonff`** — set once `sp_q` is ever read `!= 0xFFFFFFFF`.
  **1 = the read path returned real data at least once; 0 = stuck all-ones.**
- `L` low bits unchanged: `sd_ready(3) sd_err(2) ldr_done(1) ldr_error(0)`.
  Last known good read (port1 build): `sd_ready=1, ldr_done=1, ldr_error=0`
  (card read fine, a valid MCRPACK1 pack loaded).

### FIRST THING TO DO after reboot: read the beacon
```
python3 - /dev/cu.usbserial-20250414201 <<'PY'
import os,termios,select,time,re
fd=os.open('/dev/cu.usbserial-20250414201', os.O_RDONLY|os.O_NONBLOCK)
a=termios.tcgetattr(fd); a[4]=a[5]=termios.B115200
a[3]&=~(termios.ICANON|termios.ECHO|termios.ISIG); a[0]=a[1]=a[2]=0
a[2]|=termios.CS8|termios.CREAD|termios.CLOCAL
termios.tcsetattr(fd,termios.TCSANOW,a)
buf=b''; t0=time.time()
while time.time()-t0<6:
    r,_,_=select.select([fd],[],[],0.5)
    if r: buf+=os.read(fd,512)
os.close(fd)
for l in [x for x in buf.decode('ascii','replace').splitlines() if x.startswith('FB')]:
    print(l)
PY
```
(Beacon port is `/dev/cu.usbserial-20250414201`; `...200` is JTAG. The reboot
must clear the wedged BL616 — a board-only power-cycle did NOT; the bridge is
USB-C powered, so a USB-C replug / Mac reboot is required.)

### Interpreting the two numbers → the next fix
- **`x = 0000` (no writes issued):** the clk_sdram edge-detect FSM isn't
  catching `dl_wr`, or `dl_wr` isn't pulsing. Check the loader is in L_DATA and
  the clk_sys→clk_sdram crossing of `dl_wr` (they're synchronous 2:1). Scope
  `spw_count` vs a `dl_wr` counter on clk_sys.
- **`x ≈ 0x0200` but `spq_nonff = 0`:** writes are issued but the sprite read
  still returns all-ones. Most likely remaining causes, in order:
  1. **Byte-masked writes.** Sprite writes are single-byte (`ds = {a[15],
     ~a[15]}`); the memtest only ever wrote full words (`ds=2'b11`), so
     byte-masking (DQM via `SDRAM_A[12:11]` → `{DQMH,DQML}`) is UNVERIFIED.
     Test: temporarily write full words, or verify DQM timing.
  2. **sp-read latency/timing at 80 MHz.** The sp read port + its pipeline
     states (`READ1`/`READ1b`) were never exercised (memtest tied `sp_addr=0`).
     The core may latch `sp_q` before the SDRAM read completes. `sdram_gw` is a
     faithful copy of MiSTer `sdram.sv` (verified by diff — only the Gowin
     tristate + DQM-assign + RFRSH param differ), so if MiSTer works this is a
     clock-ratio issue: check MiSTer's MCR-3 SDRAM clock vs core clock ratio
     against our 80 MHz : 40 MHz.
  3. **Write address swizzle vs sp-read mapping mismatch** (should match — both
     copied from MiSTer verbatim — but re-verify the bit packing).
- **`x ≈ 0x0200` and `spq_nonff = 1`:** the data path works; the white boxes
  are a *rendering* issue (latency → the core latches the wrong beat). Look at
  the core's `sp_graphx32_do_r` latch timing vs the SDRAM read latency.

---

## Architecture / how Phase 1 is wired

- **Clock:** new `src/rtl/gowin_pll_core80.v` (60K/MCR-3 fork of
  `gowin_pll_mcr2`, **VCO = 800 MHz**): `clk_sys=40`, `clk_sdram=80`
  (= 2× clk_sys, one VCO → synchronous 1:2 crossing, no async CDC), `clk_50=50`
  (DDR3 `clk_g`). Drops the unused 125 MHz TMDS. Shared `gowin_pll_mcr2`
  (VCO=1000, the 25K's 125 MHz) is untouched.
- **Controller:** `src/rtl/sdram_gw.sv` = MiSTer MCR-3 `sdram.sv`, Gowin
  clock/tristate swap. Runs on `clk_sdram`. `RFRSH_CYCLES` is now a parameter
  (default 842 for the memtest's 100 MHz; the MCR-3 top overrides to 600 for
  80 MHz tREF). **Bank groups:** port1/cpu1-3 = banks 0/1; port2 + sp = banks
  2/3. Sprites MUST use port2 (write) + sp (read) to share bank 2/3.
- **Top (`mcr3_console60k/src/mcr3_console60k_top.sv`):**
  - `sdram_gw` on `clk_sdram`. `sp_addr = {7'd0, core_sp_addr[14:0]}`,
    `sp_q → sp_graphx32_do` (dropped the Increment-0 `32'd0` tie-off).
  - Sprite write FSM (clk_sdram): rising-edge detect on `dl_wr`, then MiSTer's
    swizzle → **port2**: `a={7'b0,dl_addr[14:0],dl_addr[16]}`,
    `ds={dl_addr[15],~dl_addr[15]}`, `d={dl_data,dl_data}`, toggle `port2_req`.
  - CPU/sound/bg stay BAKED: `cpu_rom_we=0`, `snd_rom_we=0`, core `.dl_wr(1'b0)`
    so the sprite stream can't clobber baked BSRAM.
  - SDRAM pins in `.cst` from the verified `sdram_memtest.cst` (LVCMOS33, NOT
    bank-9, coexists with DDR3). `clk_sdram` declared in `.sdc`, cut from the
    DDR3/HDMI domains (kept related to clk_sys).
- **Pack tool:** `tools/make_sprite_pack.py` → `tapper_sprite_pack.img`
  (MCRPACK1, one 128 KB slot = 8 sprite planes concatenated in MRA order).
  `rom_loader` streams the slot as `dl_addr 0..0x1FFFF`.

## Hardware / environment state at handoff

- **SD card (512 GB SDXC, `/dev/disk6` in the Mac):** Tapper sprite pack
  written at sector 2048 via `sudo dd if=tapper_sprite_pack.img of=/dev/rdisk6
  bs=512 seek=2048` (verified: 257 records, and beacon `ldr_done=1`). Card is
  **in the FPGA slot.** (Card also has an NTFS "Untitled" partition — it's the
  raw-pack card, don't worry about the filesystem.)
- **SPI flash:** the **diagnostic build** (`HEAD`) is flashed there (via
  `openFPGALoader -f`), so it boots on power-up. Screen shows white boxes.
- **Serial:** `/dev/cu.usbserial-20250414201` = UART beacon (115200),
  `...200` = JTAG. The BL616 bridge wedged after repeated flashes; a **board**
  power-cycle did not recover it (bridge is USB-C powered). Reboot / USB-C
  replug is the fix — that's why we're rebooting.

## Build / flash cheatsheet

```
GWLIB=/Applications/GowinIDE.app/Contents/Resources/Gowin_EDA/IDE/lib
GW=/Applications/GowinIDE.app/Contents/Resources/Gowin_EDA/IDE/bin/gw_sh
cd mcr3_console60k
DYLD_LIBRARY_PATH="$GWLIB" DYLD_FRAMEWORK_PATH="$GWLIB" "$GW" build.tcl
# volatile SRAM load (lost on power-off), does NOT wedge as often:
openFPGALoader -b tangconsole impl/pnr/mcr3_console60k.fs
# persistent SPI-flash load (survives power-cycle), for beacon-after-reboot:
openFPGALoader -b tangconsole -f impl/pnr/mcr3_console60k.fs
```
Post-build checks: 0 errors, 0 "Undeclared symbol", only `gowin_pll_hdmi`
PA1019, BSRAM ≤ target, positive setup/hold. (`bitstreams/*.fs` are
read-only — `chmod +w` before `cp`.)

## After the fault is fixed

1. Revert the diagnostic commit (`HEAD`) — restore the normal beacon.
2. Confirm real Tapper sprites (bartender/patrons/mugs) on screen.
3. **Phase 2:** empty CPU/sound/bg `INIT_FILE`s, extend `rom_loader` + a pack
   v2 (bigger slot) to stream the full ROM set (CPU/sound/bg → BSRAM via dl,
   sprites → SDRAM), gate boot on load-complete, "INSERT SD CARD" when absent.
   Fold `tools/make_sprite_pack.py` into `make_rompack.py`; adopt `.mra`.
4. **Phase 3:** back-port the empty-BSRAM/all-SD model to MCR-1 and the 6
   MCR-2 games.

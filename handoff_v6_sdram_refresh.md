# Handoff v6 — MCR-3 Tapper sprites: ROOT CAUSE FOUND (SDRAM refresh starvation)

**Status: the "white sprite boxes" mystery is solved with high confidence.
The sprite data is written to SDRAM correctly and reads back correctly — and
then DECAYS to all-ones within ~0.1–0.3 s because AUTO_REFRESH is running at
~2,300/s instead of the required ~133,000/s (measured, not inferred). The
remaining work is to find WHICH arbiter gate starves the refresh, fix it,
revert the diagnostics, and confirm real sprites.**

This supersedes `handoff_v5_mcr3_sprites.md` (whose "three suspects" — DQM
byte-masking, clock ratio, swizzle — are all now cleared). v4 remains the
platform reference.

---

## TL;DR of the debug session (2026-07-22)

Symptom timeline: solid white boxes → (after reboot/reflash) "vertical
flashing lines". Both are the same fault photographed at different ages:
sprites look right for the first frames after a load and rot toward
all-ones (white) as the unrefreshed DRAM cells leak. The "flashing" is cells
dying in real time; a reload (OSD A) briefly revives them.

Evidence chain, in order:

1. **Beacon after reboot** (`x0400`, `L` bit7 = 1): the SD→SDRAM write path
   issues exactly the right number of writes, and `sp_q` returns non-FF
   data. So the v5 "writes not happening / reads stuck" theories died.
2. **Swizzle re-verified verbatim** against
   `refs/Arcade-MCR3_MiSTer/Arcade-MCR3.sv` (`port2_a = {..[14:0], ..[16]}`,
   `port2_ds = {[15], ~[15]}`, `port2_d = {dout,dout}`) — identical for a
   128 KB ROM. MiSTer also runs the identical 40 MHz core / 80 MHz SDRAM
   ratio (`clk_mem = clk_80M`), so the clock-ratio suspect died too.
3. **Post-load readback sweep** (32K words re-read ~26 ms after load,
   counters in the beacon): the array holds real data structure right after
   the load (e.g. only 3,370 of 32,768 words all-FF).
4. **Full 128 KB UART dump** (~26 s): by the time each word is dumped it is
   almost entirely FF (32,509/32,768), with a small "survivor" window —
   i.e. the SAME array that had data at +26 ms is gone seconds later.
   Survivor values were partially-decayed garbage (`09090909`, `55555555`,
   four-equal-byte words = mid-death snapshots, plus DRAM's wide per-cell
   retention distribution).
5. **Triplet-read probe build** (sweep disabled, core disconnected from the
   sp bus, NOTHING reads the array first): 16 loaded cells + 4 cells
   written directly by an in-FPGA pattern writer (independent of SD!) all
   read FFFFFFFF on their FIRST-ever read ~0.1–0.3 s after being written.
   So it is not destructive reads and not the SD stream — cells die
   untouched. Pure retention failure. (JEDEC retention is 64 ms; dying at
   0.1–0.3 s with no refresh is exactly nominal behavior.)
6. **Refresh counter in `sdram_gw`** (`dbg_refresh`, beacon slot E1):
   AUTO_REFRESH commands ARE being issued but at **~2,325/s**
   (consecutive E1 samples advance 0x4D0 per 0.531 s beacon period).
   Required: 80 MHz / RFRSH_CYCLES(600) ≈ 133,000/s → every row every
   64 ms. At 2.3k/s each row is refreshed every ~3.5 s. **This is the
   root cause — a factor-57 refresh starvation.**

Why the memtest never caught it: it writes then reads back immediately
(within the retention window) and never idles long enough for decay.
Why MiSTer works: unknown yet — the refresh RTL is upstream-identical, so
the starvation must come from how OUR system leaves the arbiter gates
(port[0] idle-tied, port2/sp usage pattern) or a subtle synthesis
difference. Finding the actual blocking term is the next step, below.

## THE NEXT STEP (ready to run)

`src/rtl/sdram_gw.sv` already has two extra diagnostic counters **declared
and counting** but NOT yet wired into the top (the session ended here):

- `dbg_blk1` — RAS1 slots where refresh demand was pending but the bank2/3
  port was busy (`next_port[1] != PORT_NONE`)
- `dbg_blk0` — RAS1 slots where demand was pending, slot free, but the
  `!we_latch[0] && !oe_latch[0]` gate blocked it

Wire them into the top's beacon (E0/E2 slots are free — the sweep is
disabled in this build) exactly like `dbg_refresh`:

```verilog
// next to the dbg_refresh wire:
wire [15:0] dbg_blk0, dbg_blk1;
// in the sdram_gw instance, after .dbg_refresh(dbg_refresh):
    .dbg_blk0(dbg_blk0), .dbg_blk1(dbg_blk1)
// sample into clk_sys like dbg_refresh_s, then in the diag_x mux:
//   diag_ph==2'd0 -> dbg_blk0_s   (E0)
//   diag_ph==2'd2 -> dbg_blk1_s   (E2)
```

Interpretation: whichever counter runs at ~130k/s is what eats the demand.
- If **blk1** dominates: something makes `next_port[1]` almost always
  non-NONE — look at `port2_req ^ port2_state` (a stuck request toggle
  after the load/pattern writes?) and the `sp_addr != addr_last2[PORT_SP]`
  comparison (note `addr_last2[next_port[1]]` is written with
  `next_port[1] == PORT_REQ == 4` on port2 service — an out-of-bounds index
  into a 2-entry array; check what Gowin synthesizes that into).
- If **blk0** dominates: `we_latch[0]`/`oe_latch[0]` are getting stuck —
  look at the port[0] arbiter with all cpu addresses tied to 0 and
  `addr_last[]` power-up state (Gowin zero-inits, but verify).
- If **neither** runs fast: the demand itself (`need_refresh`) is slow —
  instrument `refresh_cnt` behavior next.

Once identified, fix, then re-run the triplet-probe build: the 20 probe
cells must read correct on read1 AND read2 AND stay correct across
snapshots for minutes. Then revert the diagnostics (list below) and check
the screen: real Tapper sprites (bartender/patrons/mugs).

Fallback fix if the arbiter subtlety stays elusive: issue refresh from the
RAS0 slot as well (port[0] is entirely idle in this design), or drop
RFRSH_CYCLES and force refresh with priority over PORT_SP when overdue by
2x. Any of these is legitimate for our single-consumer usage; prefer
understanding the real blocker first since the same controller is planned
for Phase 2 (everything-from-SD).

## What is in the working tree right now (uncommitted → committed with this handoff)

**KEEP (real fix, independent of the bug):**
- `src/rtl/sdram_gw.sv` — atomic `sp_q` commit: upstream updated
  `sp_q[15:0]` at READ1 and `[31:16]` at READ1b, so the 40 MHz consumer
  (no ack handshake on the sp port!) could sample a torn half-updated word.
  Now the first beat is buffered (`sp_q_lo`) and the full 32 bits commit in
  one cycle at READ1b. Keep this permanently.

**TEMPORARY DIAGNOSTICS (revert before shipping):**
- `src/rtl/sdram_gw.sv` — `dbg_refresh`/`dbg_blk0`/`dbg_blk1` outputs and
  their increments.
- `mcr3_console60k/src/mcr3_console60k_top.sv`:
  - readback sweep FSM (`chk_*`) — currently DISABLED (sets `chk_done`
    immediately on `ldr_done` so downstream triggers still fire);
  - post-load pattern writer (`pat_*`, plants C0..CF at words
    0x7FC0-0x7FC3 via port2 — clobbers 4 words of real sprite data);
  - triplet-read probe dump (`dump_*`, 60 lines per ~0.42 s snapshot over
    the UART: 20 cells x {read1, dummy, read2}; "========" marker line);
  - **the core is DISCONNECTED from the sp bus** (`.sp_addr({7'd0,
    dump_a})`) — sprites cannot render in this build by design;
  - beacon x/q mux (`diag_*`): E0/E2 currently show the (zeroed) sweep
    counters, E1 = `dbg_refresh` sample, E3 = `spw_count[23:8]` write
    counter; while a load is in progress x/q show the write counter raw.
  - UART TX muxed to the dump while a snapshot is printing.

To revert the temporaries later: `git log` this branch — the Increment-0 /
Phase-1 structure is unchanged underneath; the diagnostics are all in
clearly-marked `DIAGNOSTIC`/`EXPERIMENT` blocks.

## Hardware / bitstream state at handoff

- **SPI flash** (power-on default): still the v5-era diagnostic build
  (white boxes + old beacon meanings).
- **SRAM** (volatile, lost at power-off): the refresh-counter build
  (= current working tree minus the unwired blk counters).
- **SD card**: unchanged — Tapper sprite pack at sector 2048 (verified
  matching the committed `tapper_sprite_pack.img`; the pack's blob equals
  what the loader streams).
- **Serial**: on macOS the beacon was `/dev/cu.usbserial-20250414201`
  (`...200` = JTAG). On Linux expect two ttyUSB/ttyACM nodes from the
  BL616; the beacon is the one speaking 115200 8N1 "FB ..." lines.
  BL616 wedge note still applies: after repeated flashing the UART can go
  silent; replug USB-C (board power-cycle alone does not clear it).

## Reference numbers for the offline analysis

Expected sweep counters for a PERFECT SDRAM image of the committed
`tapper_sprite_pack.img` (header sector + 128 KB blob; word i is bytes
blob[i], blob[0x8000+i], blob[0x10000+i], blob[0x18000+i] low→high):
**allff = 51, "both DQML lanes FF" = 87, "both DQMH lanes FF" = 105.**
The triplet-probe expected pattern words at 0x7FC0..3:
`C3C2C1C0 C7C6C5C4 CBCAC9C8 CFCECDCC`.

Serial capture snippet (adjust device path on Linux):

```python
import os,termios,select,time,sys
fd=os.open('/dev/ttyUSB1', os.O_RDONLY|os.O_NONBLOCK)
a=termios.tcgetattr(fd); a[4]=a[5]=termios.B115200
a[3]&=~(termios.ICANON|termios.ECHO|termios.ISIG); a[0]=a[1]=a[2]=0
a[2]|=termios.CS8|termios.CREAD|termios.CLOCAL
termios.tcsetattr(fd,termios.TCSANOW,a)
t0=time.time()
while time.time()-t0<40:
    r,_,_=select.select([fd],[],[],0.5)
    if r: sys.stdout.write(os.read(fd,4096).decode('ascii','replace'))
os.close(fd)
```

(If you timestamp chunks, strip the injected markers BEFORE splitting
lines — a marker can land mid-line and corrupt the 8-hex parse.)

## Loose ends spotted along the way (not blocking, tracked here)

1. **Boot sometimes needs OSD-in/out + A before Tapper starts.** The
   loader's write counter showed 0x0200 (one clean pass) on some boots and
   0x0400 (two passes) on others; `ldr_done` did rise on every observed
   boot. Suspected: SD card left mid-command by reconfiguration, and/or the
   prefs-consulting boot path. Diagnose after the refresh fix (the OSD-A
   workaround is fine meanwhile).
2. **PR1014 warning on `sys_clk_d`** appears in current builds (raw 50 MHz
   pad fanning out to three PLL clkins). Nothing clock-structural changed
   this session and the previous session's logs were overwritten, so it is
   believed pre-existing. If DDR3/HDMI ever fails to come up on a rebuild,
   revisit (cf. the clk_g PR1014 history in CLAUDE.md).
3. First build of the session had hold slack +0.001 ns (later builds
   +0.15 ns). Keep an eye on hold after reverting diagnostics.
4. `sdram_gw` writes `addr_last2[next_port[1]]` with `PORT_REQ = 4` into a
   2-entry array (upstream MiSTer code does the same). Believed harmless
   (the aliased/dropped entry is never compared), but verify while fixing
   the refresh starvation since it is in the exact code being touched.

## Build / flash cheatsheet (Linux)

```sh
# Gowin IDE for Linux: gw_sh is at <install>/IDE/bin/gw_sh, no DYLD_* needed
cd mcr3_console60k
<gowin>/IDE/bin/gw_sh build.tcl
# volatile SRAM load:
openFPGALoader -b tangconsole impl/pnr/mcr3_console60k.fs
# persistent SPI flash (power-on default):
openFPGALoader -b tangconsole -f impl/pnr/mcr3_console60k.fs
```

Post-build checks (per CLAUDE.md): 0 errors, `grep -i "Undeclared symbol"
impl/gwsynthesis/*.log` empty, only `gowin_pll_hdmi` PA1019, positive
setup/hold in `impl/pnr/*.timing_paths`.

## After the refresh fix lands

1. Revert the temporary diagnostics (see list above) — including
   re-connecting the core to the sp bus and restoring the normal beacon.
2. Confirm real Tapper sprites on screen over minutes (not seconds).
3. Investigate loose end #1 (boot-hang-until-OSD) if it persists.
4. Resume the v5 plan: Phase 2 (everything-from-SD, empty BSRAM), then
   Phase 3 (back-port to MCR-1/MCR-2).

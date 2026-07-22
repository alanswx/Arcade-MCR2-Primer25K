# Universal MCR Shield — Consolidated Specification

Single source of truth for the cabinet-interface shield that lets a Tang
Console 60K/138K drop into any original Bally Midway MCR-1/2/3 cabinet as a
CPU-board replacement. Consolidates and supersedes the electrical/pinout
content spread across `handoff_v2_design.md` (§2–3, written for the Primer
25K dock) and `pcb_design.md` (floorplan/KiCad, still authoritative for
layout). Game-function reference: `docs/mcr_game_input_matrix.md`.

## 0. Product decisions (2026-07, settled)

- **Interface style: the cabinet harness plugs into the shield** (settled
  2026-07-22). The shield presents the original MCR cabinet connectors as
  headers; the operator plugs the existing harness in and picks the game in
  the OSD — no rewiring, because the FPGA maps every pin to its in-game
  function per the selected game (the '165 chain delivers raw bits; the core
  interprets them). This is explicitly **NOT** a mechanical board-swap
  (the shield does not plug into the cabinet's original PCB-edge socket in
  place of the game board — that would mean replicating each board's edge
  connector and is out of scope). Consequences for the PCB:
  - Route the actual MCR **mating connectors** in the right positions so an
    original harness seats pin-for-pin.
  - **Rev A targets the SSIO-family connectors** (MCR-1/2 + the SSIO MCR-3
    games: Tapper, Timber, Journey, Discs of Tron, Spy Hunter, Crater) —
    the large majority, and the set documented in the master pinout matrix.
  - **MCR3Mono (Rampage, Sarge, Max RPM, Power Drive, Star Guards) is a
    later variant**: those games are absent from the master pinout matrix
    and the mono board routes IP ports to different connectors (IP0/IP1→J2,
    IP2→J3, IP4→J4, 3 players) — verify against the mono board schematic
    before adding its connectors.
  - Special controls (dials/spinners/wheels/pedals) arrive as **8-bit
    digital** on the Opt X/Opt Y connectors; the shield reads them straight
    from a cabinet that still has its MCR control PCB. A bare-pot hookup
    would need an ADC the shield does not provide (silkscreen note).
- **Dual-use, not cabinet-only.** Keep the HDMI path alongside the analog
  cabinet output: it is the primary debug surface, and retrofit-LCD cabinets
  are a real installed base. Consequence: the DDR3 framebuffer stays, so
  **DDR3 is committed to video** and cannot also serve as the ROM store.
- **ROM storage split (as nand2mario/gbatang does on this exact board):**
  DDR3 → framebuffer; **SDRAM module in the J9 slot → game ROMs** for sets
  too big for BRAM; SD card → ROM files and firmware.
- **Configuration by DIP switches, read through a 74HC165 chain** (3 pins
  for 16 switches). Parallel DIPs do not fit: the shield needs 44 of the 54
  I/O available on J10+PMODs, and spending J9 on switches would forfeit the
  SDRAM slot. See §7.
- **Cabinet default is menu-off**: power on straight into the DIP-selected
  game, no OSD reachable by a customer.

## 1. Design principles

1. **Expose the original MCR connectors** so the cabinet harness plugs
   straight in — no JAMMA adaptation. The real board connectors, their
   pin counts and **pitch** (J1 power = .156" MTA; J2 video, J3 audio,
   J4/J5/J6 inputs = .100" MTA) and per-pin functions are in
   **`docs/shield_wiring.md`** / **`docs/MCR Series Pinouts.html`**. (The
   matrix doc uses a normalized *cabinet-function* J-numbering; the
   physical connectors use the real board numbering — see shield_wiring §1.)
2. **No game-specific wiring.** Connector wiring is identical across all
   MCR games; every game-specific *interpretation* lives in the FPGA top.
   One shield serves every core. (DIP switches select which game/core runs
   — they do not rewire anything.)
3. **Serial cabinet I/O — no opto isolation (revised 2026-07).** Cabinet
   inputs run into 74AHC165 shift registers (3 FPGA pins), outputs via a
   74HC595 chain (4 pins); see `shield_wiring.md`. The 74AHC165's 5.5 V-
   tolerant inputs take the 5 V harness directly, so there is no separate
   level shifter. The earlier plan (parallel, opto-isolated) was dropped:
   the shield's buck is non-isolated, so the optos never bought isolation,
   and parallel I/O would forfeit the J9 SDRAM slot (§2).

## 2. FPGA signal budget

**Revised 2026-07-21: the shield connects to J10 ONLY** — one 40-pin
header for video, audio and all controls; both PMOD sockets stay free.
The definitive pin table is **`shield_j10_pinout.md`**; the budget that
makes it fit:

| Group | J10 pins | Direction | Interface |
|---|---:|---|---|
| Video RGB (4:4:4 driven, 3:3:3 significant) | 12 | out | R2R DAC → 1 Vp-p |
| Video sync HS/VS | 2 | out | NPN/74HCT buffer → 5V TTL |
| Audio PWM L/R | 2 | out | RC filter → LM386 |
| Status LEDs | 4 | out | direct |
| Mode/sync straps | 3 | in | solder jumpers |
| **ALL cabinet inputs + both DIP banks** (J2, J3, J4, J5, J6/IP4, SW1, SW2 = 56 bits) | **3** | in | 7× 74AHC165 chain (5 V-tolerant inputs) |
| **All outputs** (coin meters, lamps — mono drives output_5+output_6 = 16 bits) | 4 | out | 2× 74HC595 chain + ULN2803 |
| Service button | 1 | in | direct (opens the OSD) |
| Spares | 7 | — | |
| Power (+5 V out, GND) | 2 | | |
| **Total** | **40** | | |

Serializing the inputs is what makes "every game on one header" possible:
30+ harness lines plus the 8-bit IP4/J6 port plus 16 DIPs would need ~60
parallel pins, forfeiting either video or the J9 SDRAM slot (i.e. the big
MCR-3 titles). The '165 parallel-load strobe snapshots all 56 bits
atomically, so the 8-bit spinner/trackball buses cannot tear, and a full
scan (~30 µs) is ~500× faster than the games' own once-per-frame input
polling. HDMI, USB, SD and DDR3 cost zero shield pins (SOM/dock balls).

## 3. Electrical interface (consolidated)

- **Power:** cabinet +12 V → onboard buck (LM2596/MP1584EN, ≥1.5 A) → 5 V to
  the Console's 5 V input. Do not use the cabinet's +5 V rail (noise/brownout)
  or −5 V rail (not needed — no 4116 DRAMs).
- **Inputs (revised 2026-07-21 — no optos):** harness lines go directly
  into the shield's **74AHC165** shift registers, powered at 3.3 V — AHC
  inputs are rated to 5.5 V independent of VCC, so the '165 itself does
  the 5 V → 3.3 V translation. Per line: 4.7 kΩ pull-up to +5 V, 1 kΩ
  series, 10 nF to GND, BAT54S clamp to +5 V/GND (a 12 V miswire drops
  across the series R). Full pad + rationale in `shield_j10_pinout.md`
  §2/§3b. The earlier TLP281-4 opto plan claimed galvanic isolation the
  non-isolated buck never actually allowed (grounds are common through
  the power path); the pads keep the fault protection at a fraction of
  the parts. Plain 74HC165 is NOT a substitute (inputs limited to
  VCC + 0.5 V).
- **Video RGB:** R2R ladder per gun (510 Ω / 1 kΩ / 2 kΩ for bits 2/1/0)
  into the monitor's 75 Ω load ≈ 1 Vp-p. No active buffer needed.
- **Video sync:** 3.3 V FPGA → BC847 NPN stage (or 74HCT244 powered at 5 V)
  → 5 V TTL negative-going HS/VS on Video-8/9. G07/K4600-style monitors at
  15 kHz; the core must be in `tv15Khz_mode=1` for a real MCR cabinet
  monitor.
- **Audio:** PWM → 2-stage RC low-pass (~15 kHz) → LM386 (12 V rail) → mono
  speaker terminals.

## 4. Dock connector plan (from schematic `Tang_Mega_60K_Console_32001C`, rev 1.3)

The dock's two 2×20 headers are **J9 ("SDRAM0 CONN", near PCIe)** and
**J10 ("SDRAM1 CONN", near the PMODs)** — each carries a full 38-signal
SDRAM-pinout GPIO bus. Architecture decision:

- **J9 — reserved for the Tang SDRAM module** (future frame buffer / ROM
  store; nand2mario cores use these exact pins, `cs_n = F21` on this rev).
- **J10 + PMOD0 + PMOD1 — the shield** (38 + 16 = 54 IOs for ~44 nets).
- USB-A ports remain the controller path; HDMI remains for modern displays.

### 4a. J10 header ↔ FPGA ball map (verified: sheets 4, 6, 8 of rev C PDF)

| J10 pin | Net | Ball | J10 pin | Net | Ball |
|---|---|---|---|---|---|
| 1 | D0 | R19 | 2 | D1 | P19 |
| 3 | D2 | U21 | 4 | D3 | T21 |
| 5 | D4 | R17 | 6 | D5 | P16 |
| 7 | D6 | T18 | 8 | D7 | R18 |
| 9 | D15 | W17 | 10 | D14 | V17 |
| 11 | **+5V** | — | 12 | **GND** | — |
| 13 | D13 | W22 | 14 | D12 | W21 |
| 15 | D11 | P17 | 16 | D10 | N17 |
| 17 | D9 | N14 | 18 | D8 | N13 |
| 19 | A12 | V20 | 20 | CLK | U20 |
| 21 | A9 | Y22 | 22 | A11 | Y21 |
| 23 | A7 | AB22 | 24 | A8 | AB21 |
| 25 | A5 | AA21 | 26 | A6 | AA20 |
| 27 | WE | AB20 | 28 | A4 | AA19 |
| 29 | EXIO0 (=DM0 via 0Ω) | AA18 | 30 | EXIO1 (=DM1 via 0Ω) | AB18 |
| 31 | CAS | Y19 | 32 | RAS | Y18 |
| 33 | CS | T20 | 34 | BA0 | N15 |
| 35 | BA1 | U18 | 36 | A10 | U17 |
| 37 | A0 | R16 | 38 | A1 | P15 |
| 39 | A2 | R14 | 40 | A3 | P14 |

Caveats: **V17 = CSI_B, AB20 = CSO_B/DOUT, AA19 = RDWR_B** are config
dual-purpose pins — synthesis needs the matching `-use_sspi_as_gpio`-family
options (the 25K build.tcl shows the pattern). U20/V20 are GCLK-capable
(bonus, not required). All J10 banks (6/7/8) are 3.3 V.

### 4b. Cabinet pin → J10/PMOD assignment — SUPERSEDED

> **This section is superseded by `shield_j10_pinout.md`** (2026-07-21),
> which puts everything on J10 via input/output shift-register chains and
> keeps the PMODs free. It is retained only as the record of the earlier
> parallel-input plan; do not route from it.

Inputs (all opto-isolated, active low, internal pull-ups):

| Cabinet pin | Function | J10 pin | Ball |
|---|---|---|---|
| J4-1..7,9 | Opt X D0–D7 (dial bus) | 1,2,3,4,5,6,7,8 | R19,P19,U21,T21,R17,P16,T18,R18 |
| J5-1..6 | Opt Y D0–D5 | 18,17,16,15,14,13 | N13,N14,N17,P17,W21,W22 |
| J5-15 | Opt Y D6 / P2 Up | 10 | V17 |
| J5-16 | Opt Y D7 / P2 Down | 9 | W17 |
| J5-17 | P2 Left | 36 | U17 |
| J5-18 | P2 Right | 22 | Y21 |
| J5-19 | P2 Button 1 | 19 | V20 |
| J2-1..6 | P1 Up,Down,Left,Right,B1,B2 | 37,38,39,40,28,25 | R16,P15,R14,P14,AA19,AA21 |
| J3-1..5 | Coin1,Coin2,Start1,Start2,Tilt | 26,23,24,21,34 | AA20,AB22,AB21,Y22,N15 |
| reserved (outputs: coin meters / lamps / J6) | — | 20,27,31,32,33,35,29,30 | U20,AB20,Y19,Y18,T20,U18,AA18,AB18 |

Video/audio on the PMODs (shield covers both sockets):

| Signal | PMOD | Ball |
|---|---|---|
| VID_R[2:0] (R2R) | PMOD0 | V18, V19, G21 |
| VID_G[2:0] (R2R) | PMOD0 | G22, F18, E18 |
| VID_B[2:1] (R2R) | PMOD0 | C22, B22 |
| VID_B[0] (R2R) | PMOD1 | W19 |
| VID_HS / VS / CSYNC (5V TTL buf) | PMOD1 | W20, F19, F20 |
| AUD_PWM_L / R | PMOD1 | E22, D22 |
| spare | PMOD1 | E21, D21 |

**Note:** the current `mcr2_console60k.cst` desk-test assignments (buttons
on PMOD1, provisional cab video) intentionally differ; re-pin to this table
when shield rev A is finalized — cabinet inputs then arrive via the J10
74AHC165 chain and the USB pad, so PMOD desk buttons retire.

+12 V from the cabinet enters the shield at a screw terminal → buck → 5 V.

## 5. RTL requirements per game core

- `tv15Khz_mode = 1` for cabinet use (native 15 kHz RGBS); HDMI path stays
  active concurrently for bring-up.
- Input mapping from nets above into `input_0..input_4` per game, bit
  positions verified against MAME (`mcr.cpp`) — see examples in
  `mcr_game_input_matrix.md`.
- Spinner/trackball (J4/J5 8-bit buses) feed the core's `spinner.sv` /
  analog paths — only needed for dial games (Tron, Kick, Kozmik, Wacko,
  DoT, Spy Hunter).

## 6. Open items

(Also tracked in the repo-root `TODO.md`, alongside the gateware gaps.)

1. **5 V delivery route** — shield buck → console. Preferred: into the
   dock's USB-C power input (goes through the dock's OR-ing/OVP, sheet 3).
   J10 pin 11 exposes a +5 V rail, but whether back-feeding it powers the
   SOM cleanly (it sits behind the OR-ing/OVP/bead chain) is unverified —
   do not use it as an input until traced.
2. **Board revision** — ✅ checked: J10's header pinout is net-for-net
   identical in rev A (32001A, 1.22) and rev C (32001C, 1.3); only the
   footprint differs (TH vs SMD 2×20). Ball map in §4a is from rev C's SOM
   sheets; if a board is identified as rev A, spot-check sheets 4/6 (the
   only known dock-level reroute is SDRAM0_CS: F19 on the old NEO dock →
   F21 now — J9 side, doesn't affect the shield).
3. **J6 / SSIO IP4** and **lamp/coin-meter outputs** — ✅ resolved by the
   chain architecture in `shield_j10_pinout.md`: IP4/J6 is '165 device U5
   (8 bits, zero extra pins) and outputs are a 74HC595+ULN2803 chain,
   extensible per game with no pin cost. J6's *cabinet-side* connector
   wiring still wants a manual cross-check before the harness is crimped.
4. **Board outline/mounting** — `pcb_design.md` + `tools/generate_pcb.py`
   own the physical layout; sync them to §4b (they currently assume generic
   2×20 headers, and J9 must be left clear for the SDRAM module).
5. **138K variant** — same dock; header nets are dock-level, but the
   net→ball map on sheets 4–6 is SOM-specific. Re-extract from the 138K
   SOM schematic before targeting it.

---

## 7. Configuration & game selection (DIP switches)

Two 8-position DIP banks, matching the SW1/SW2 placement already in
`pcb_design.md`. **Revised 2026-07-20:** game *selection* moves to the OSD
(see 7c/7d); the physical DIPs are for what operators have always used DIPs
for — the game's own option switches.

### 7a. Switch map

| Bank | Positions | Function |
|---|---|---|
| SW1 | 1–8 | **GAME DIPS — wired verbatim as the core's IP3 byte** (the original board's B3 bank). Meanings are per game, exactly as the 1982 operator manuals document them: coinage, music, difficulty, cabinet type, coin meters… Ship a printed reference card per game, as operators always had. |
| SW2 | 1 | Menu enable (see 7c) |
| SW2 | 2 | Video: 15 kHz cabinet CRT / 31 kHz |
| SW2 | 3 | 15 kHz sync format: separate H/V (default, = MCR cabinet) / composite |
| SW2 | 4 | Free play (where the game's own DIPs lack it) |
| SW2 | 5 | Service / test |
| SW2 | 6–8 | Reserved |

SW1 = IP3 removes the per-game hardcoded `input_3` constants from the top —
the operator sets the real switches. Two caveats survive from the analysis
below: the cocktail bit lives at a different IP3 position per game (that is
now simply the operator's problem to set per the game's card, as it was in
1982), and **IP3 is not purely DIPs for every game** — Tron's bit 7 is the
cocktail player's fire button. The original hardware wired that harness
line in parallel with DIP position 8 on the same active-low input, and the
manual said "leave SW1-8 OFF". We replicate it exactly: the FPGA ORs the
switch bit with the harness line, no per-game masking — same behaviour,
same operator convention, including the same failure mode if the switch is
left on.

**Cocktail pin impact:** unchanged — cocktail P2 controls for Tron/Domino
arrive on SSIO IP2 = J5 1-8, already allocated in §4b. The outstanding item
is **IP4 / J6**, which §4b does not pin: it carries Wacko's cocktail
joystick, Two Tigers' P2 dial, and Kroozr's analogue-stick Y axis (the last
needed even upright). Allocate from the 8 reserved pins once J6's cabinet
wiring is established.

### 7b. Reading them (74AHC165)

The two DIP banks are simply devices **U6 (SW1) and U7 (SW2) on the
unified input chain** defined in `shield_j10_pinout.md` §3 (IN_CLK /
IN_LOAD_N / IN_DATA on J10 pins 25/26/27) — the same chain that carries
every harness input, so the DIPs cost zero additional pins. Switch to GND
with pull-ups to +3V3; a closed switch reads 0. Because the chain is
scanned continuously, DIP changes could be live — but the cores latch IP3
meaningfully only at boot, so keep the **silkscreen "power-cycle after
changing DIPs"** next to the banks.

### 7c. OSD (game selection & system settings)

Game selection is on-screen, opened with the **cabinet's existing service
button** (present in every MCR harness) or the bench board key. Selection
and system prefs persist to a reserved SD sector; the chosen game reloads
via the existing rom_loader path, no reflash.

**The OSD must be visible on BOTH video outputs.** It composites into the
core's native RGB stream *before* the analog/HDMI split (clk_sys domain, on
the native raster), so the cabinet CRT — the only display in a cabinet —
shows it identically to HDMI. Consequences the implementation must honour:
- **per-game rotation**: vertical games (Tron, Satan's Hollow, Kick…) run
  on physically rotated monitors, so OSD text must render ROT90 for them;
- works on the **15 kHz raster** (240-line fields), not just 31 kHz;
- native resolution and the game palette's 3:3:3 colour — which is
  authentic-looking, not a limitation.

Menu semantics:
- **Menu off (SW2-1, cabinet default):** customers cannot reach the OSD;
  the service button still opens it (operator path, as MCR test switches
  always worked).
- **Menu on:** OSD reachable from the pad (bench/home use).

### 7d. Multiboot layout

Per-core bitstream payload is **2.5 MB** (`impl/pnr/*.bin`; the 20 MB `.fs`
is ASCII, not the flash footprint), so all three family cores fit in <8 MB.
A small selector image boots first, reads the prefs sector from SD (last
selected family/game), and reconfigures to that image's flash address.
`-multi_boot 1` is already set in `build.tcl`. No switches involved.

### 7e. Fallback behaviour (required for shipping)

If the selected family/game has no ROMs available (missing SD card, missing
file, bad checksum): **do not sit on a black screen.** Flash a status code
on an LED and fall back to the menu (or to a built-in test pattern when the
menu is disabled), so a field failure is diagnosable without a laptop.

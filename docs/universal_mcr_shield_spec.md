# Universal MCR Shield — Consolidated Specification

Single source of truth for the cabinet-interface shield that lets a Tang
Console 60K/138K drop into any original Bally Midway MCR-1/2/3 cabinet as a
CPU-board replacement. Consolidates and supersedes the electrical/pinout
content spread across `handoff_v2_design.md` (§2–3, written for the Primer
25K dock) and `pcb_design.md` (floorplan/KiCad, still authoritative for
layout). Game-function reference: `docs/mcr_game_input_matrix.md`.

## 0. Product decisions (2026-07, settled)

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

1. **Expose the original MCR connectors** (J2, J3, J4, J5, Video, power,
   audio) so the cabinet harness plugs straight in — no JAMMA adaptation.
2. **No game-specific wiring.** Connector wiring is identical across all
   MCR games (see the matrix doc); every game-specific *interpretation*
   lives in the FPGA top. One shield serves every core. (DIP switches
   select which game/core runs — they do not rewire anything.)
3. **Parallel, opto-isolated cabinet I/O.** Every cabinet input gets its own
   opto-isolated FPGA pin. Only the DIP switches are read serially, to keep
   the J9 expansion slot free.

## 2. FPGA signal budget

| Group | Signals | Direction | Interface |
|---|---:|---|---|
| J2 (P1) | 6 | in | opto, active low |
| J3 (coin/start/tilt) | 5 | in | opto, active low |
| J4 (Opt X, 8-bit dial bus) | 8 | in | opto, active low |
| J5 (Opt Y / P2) | 11 | in | opto, active low |
| Video RGB | 9 (3:3:3) | out | R2R DAC → 1 Vp-p |
| Video sync | 2–3 (HS, VS, opt. CSYNC) | out | NPN/74HCT buffer → 5V TTL |
| Audio | 1–2 (PWM) | out | RC filter → LM386 |
| DIP config (16 switches) | 3 | in | 74HC165 chain (§7) |
| **Total** | **~47** | | |

Available to the shield: **54 I/O** = J10's 38 signal pins (40 less +5V/GND
at 11/12) + PMOD0 (8) + PMOD1 (8). That leaves ~7 spare for coin meters and
lamps, and keeps **J9 (38 pins) entirely free for the SDRAM module**.
HDMI costs zero shield pins (TMDS is on dedicated SOM balls); likewise the
USB-A ports, SD card, and DDR3 are all on SOM/dock pins.

Note this is why the DIPs are serial: 16 parallel DIP pins would need 60
I/O, forcing the design into J9 and forfeiting the SDRAM slot — i.e. giving
up the big MCR-3 titles to save a 15-cent shift register.

## 3. Electrical interface (consolidated)

- **Power:** cabinet +12 V → onboard buck (LM2596/MP1584EN, ≥1.5 A) → 5 V to
  the Console's 5 V input. Do not use the cabinet's +5 V rail (noise/brownout)
  or −5 V rail (not needed — no 4116 DRAMs).
- **Inputs:** TLP281-4 quad optos, cabinet side pulled to +5 V through
  4.7 kΩ; output transistor pulls the FPGA pin (internal pull-up, 3.3 V) to
  GND. 100% galvanic isolation of all 30 input lines (8 × TLP281-4).
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

### 4b. Cabinet pin → J10/PMOD assignment

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
when shield rev A is finalized — cabinet inputs then arrive via J10 optos
and the USB pad, so PMOD desk buttons retire.

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
3. **J6 / SSIO IP4** and **lamp/coin-meter outputs** — not in the matrix
   PDF; 8 J10 pins are reserved for them. Survey MAME + cabinet manuals
   before finalizing rev A (outputs need driver transistors, not optos).
4. **Board outline/mounting** — `pcb_design.md` + `tools/generate_pcb.py`
   own the physical layout; sync them to §4b (they currently assume generic
   2×20 headers, and J9 must be left clear for the SDRAM module).
5. **138K variant** — same dock; header nets are dock-level, but the
   net→ball map on sheets 4–6 is SOM-specific. Re-extract from the 138K
   SOM schematic before targeting it.

---

## 7. Configuration & game selection (DIP switches)

Two 8-position DIP banks, matching the SW1/SW2 placement already in
`pcb_design.md` — and matching what MCR operators expect, since the original
boards were configured the same way.

### 7a. Switch map

| Bank | Positions | Function |
|---|---|---|
| SW1 | 1–2 | **Family** → selects which bitstream multiboot loads: MCR-1 / MCR-2 / MCR-3 / (reserved) |
| SW1 | 3–5 | **Game within family** (8 slots; no family has more) |
| SW1 | 6–8 | Reserved (ROM revision, region, future families) |
| SW2 | 1 | **Menu enable** (see 7c) |
| SW2 | 2 | Video: 15 kHz cabinet CRT / 31 kHz |
| SW2 | 3 | Cabinet: upright / cocktail (costs no extra pins — see note) |
| SW2 | 4 | Free play |
| SW2 | 5 | Service / test |
| SW2 | 6–8 | Reserved |

SW2-2 supersedes the `mode15_n` bench strap; SW2-3 feeds the per-game
cocktail DIP bit (e.g. Domino IP3 bit 6 — see the game input matrix).

**How SW2-3 reaches the core:** `input_3`/IP3 *is* the original board's B3
DIP bank as read by the SSIO — an internal core signal. The switch travels
SW2-3 -> 74HC165 -> FPGA -> the game's cabinet bit in `input_3` (bit 1 for
Tron/Satan's Hollow, bit 6 for Domino/Wacko/Kroozr; Two Tigers has none).
Note IP3 is not purely DIPs: Tron carries the cocktail player's fire button
on its bit 7, so that bit must come from a cabinet input line, not a config
switch - and where it lands on the harness is undocumented (see TODO.md).

**Cocktail pin impact:** none for the switch itself (the 74HC165 chain is a
fixed 3 pins for up to 16 switches), and cocktail player-2 controls for
Tron/Domino arrive on SSIO IP2 = J5 1-8, already allocated in §4b. The
outstanding item is **IP4 / J6**, which §4b does not pin: it carries Wacko's
cocktail joystick, Two Tigers' P2 dial, and Kroozr's analogue-stick Y axis
(the last needed even upright). Allocate from the 8 reserved pins once J6's
cabinet wiring is established. Note also that IP3 is not purely DIPs — Tron
puts the cocktail fire button on its bit 7.

### 7b. Reading them (74HC165)

Two 74HC165s daisy-chained (SW1 → SW2), read with 3 FPGA pins. Suggested
J10 assignment, taken from the pins §4b reserves for outputs:

| Signal | J10 pin | Ball | Note |
|---|---|---|---|
| `dip_clk` | 20 | U20 | GCLK-capable |
| `dip_load` (SH/LD̄) | 31 | Y19 | |
| `dip_data` (QH of last device) | 32 | Y18 | |

Switch to GND with pull-ups to +3V3; a closed switch reads 0. Sampled once
after reset — **silkscreen "power-cycle after changing DIPs"** next to the
banks. No debounce needed.

### 7c. Menu semantics

- **Menu off (cabinet default):** boot straight into the DIP-selected game.
  No OSD exists at runtime; nothing a customer can reach.
- **Menu on:** the DIPs still choose the boot default, but the OSD can
  override at runtime (bench/home/multicade use).

### 7d. Multiboot layout

Per-core bitstream payload is **2.5 MB** (`impl/pnr/*.bin`; the 20 MB `.fs`
is ASCII, not the flash footprint), so all three family cores fit in <8 MB.
A small selector image boots first, samples the DIPs, and reconfigures to
the chosen image's flash address. `-multi_boot 1` is already set in
`build.tcl`.

### 7e. Fallback behaviour (required for shipping)

If the selected family/game has no ROMs available (missing SD card, missing
file, bad checksum): **do not sit on a black screen.** Flash a status code
on an LED and fall back to the menu (or to a built-in test pattern when the
menu is disabled), so a field failure is diagnosable without a laptop.

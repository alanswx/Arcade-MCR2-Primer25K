# Shield ↔ Tang Console 60K: the J10 40-pin header (rev A freeze)

**This is the authoritative pin sheet for the shield PCB.** It supersedes
the draft net plan in `universal_mcr_shield_spec.md` §4b (which spread
video onto the PMOD sockets); the shield now connects to **J10 only** —
video, audio and all controls on one 40-pin header, both PMOD sockets left
free. Electrical details (optos, DAC values, buck) stay in the spec §3.

Ground rules:

- **Interface style (settled): the cabinet harness plugs into the shield.**
  The shield presents the original MCR mating connectors; the operator plugs
  the existing harness in and selects the game in the OSD — the FPGA maps
  every pin to its in-game function, so nothing is rewired. This is NOT a
  mechanical board-swap. **Rev A targets the SSIO-family connectors** (most
  games); MCR3Mono is a later variant. Full rationale + the connector
  target in `universal_mcr_shield_spec.md` §0.
- **Every J10 signal is 3.3 V LVCMOS (banks 6/7/8). Nothing is 5 V
  tolerant.** Cabinet-side 5 V never reaches a header pin: inputs land on
  the shield's **74AHC165s** (5.5 V-tolerant inputs — §2), never on the
  FPGA directly; sync/video leave through buffers/ladders.
- Pins marked **live** are driven by the bitstreams shipping today —
  video/audio works on the board the day it is soldered, with no gateware
  change. Pins marked **reserved** are allocated here and safe to route
  now; the expander RTL that drives them is a small, planned change
  (`TODO.md`). Until then they are high-Z from the FPGA.
- J10 is the 2×20, 2.54 mm header **nearest the PMOD sockets** (the other
  2×20, J9, is the SDRAM slot — the shield must leave it unobstructed).
  Odd/even pins face each other; anchor orientation electrically at
  **pin 11 = +5 V / pin 12 = GND**. Header is net-for-net identical on
  dock rev A (32001A) and rev C (32001C); ball map from the rev C SOM
  sheets (spec §4a/§6.2).

## 1. The 40 pins

| Pin | Ball | Net | Dir (FPGA) | Status | Function |
|---:|---|---|---|---|---|
| 1 | R19 | `VID_R0` | out | live | red bit 0 (= copy of bit 3; DAC may ignore) |
| 2 | P19 | `VID_R1` | out | live | red bit 1 → 2 kΩ |
| 3 | U21 | `VID_R2` | out | live | red bit 2 → 1 kΩ |
| 4 | T21 | `VID_R3` | out | live | red bit 3 (MSB) → 510 Ω |
| 5 | R17 | `VID_B0` | out | live | blue bit 0 (copy of bit 3) |
| 6 | P16 | `VID_B1` | out | live | blue bit 1 → 2 kΩ |
| 7 | T18 | `VID_B2` | out | live | blue bit 2 → 1 kΩ |
| 8 | R18 | `VID_B3` | out | live | blue bit 3 (MSB) → 510 Ω |
| 9 | W17 | `SPARE0` | — | spare | |
| 10 | V17 | `SPARE1` | — | spare | CSI_B config pin — needs the `-use_sspi_as_gpio` build option (already set) |
| 11 | — | **+5 V** | — | power | rail **out of** the dock; light loads only; do NOT back-feed (spec §6.1) |
| 12 | — | **GND** | — | power | star ground for the shield |
| 13 | W22 | `VID_G0` | out | live | green bit 0 (copy of bit 3) |
| 14 | W21 | `VID_G1` | out | live | green bit 1 → 2 kΩ |
| 15 | P17 | `VID_G2` | out | live | green bit 2 → 1 kΩ |
| 16 | N17 | `VID_G3` | out | live | green bit 3 (MSB) → 510 Ω |
| 17 | N14 | `VID_HS` | out | live | HSync, negative; carries **CSYNC** when strap pin 39 = GND |
| 18 | N13 | `VID_VS` | out | live | VSync, negative |
| 19 | V20 | `SPARE2` | — | spare | GCLK-capable |
| 20 | U20 | `SPARE3` | — | spare | GCLK-capable |
| 21 | Y22 | `LED_CALIB` | out | live | status LED: DDR3 trained (steady on = good) |
| 22 | Y21 | `LED_PIX` | out | live | status LED: pixel-clock heartbeat ~1 Hz |
| 23 | AB22 | `LED_27M` | out | live | status LED: 27 MHz heartbeat ~0.8 Hz |
| 24 | AB21 | `LED_DDR_RST` | out | live | status LED: DDR reset (steady OFF = good) |
| 25 | AA21 | `IN_CLK` | out | reserved | 74HC165 chain shift clock (≤2 MHz) |
| 26 | AA20 | `IN_LOAD_N` | out | reserved | 74HC165 SH/LD̄ — low pulse snapshots all inputs atomically |
| 27 | AB20 | `IN_DATA` | in | reserved | serial data from U7.QH (CSO_B config pin — option already set) |
| 28 | AA19 | `OUT_CLK` | out | reserved | 74HC595 chain shift clock (RDWR_B config pin — option already set) |
| 29 | AA18 | `SPARE4` | — | spare | EXIO0: 0 Ω-linked to DM0 net on the dock — verify before use |
| 30 | AB18 | `SPARE5` | — | spare | EXIO1: 0 Ω-linked to DM1 — same caveat |
| 31 | Y19 | `OUT_DATA` | out | reserved | serial data to U8.SER |
| 32 | Y18 | `OUT_LATCH` | out | reserved | 74HC595 RCLK — output register update |
| 33 | T20 | `SERVICE_N` | in | reserved | cabinet service button, direct (opens the OSD); shield pull-up to 3V3 |
| 34 | N15 | `OUT_EN_N` | out | reserved | 74HC595 OE̅. **Shield MUST pull up to 3V3** so meters/lamps stay off until the RTL drives it low |
| 35 | U18 | `AUD_PWM_L` | out | live | PWM audio left → RC filter → amp (spec §3) |
| 36 | U17 | `AUD_PWM_R` | out | live | PWM audio right (mono cabinets: use L only) |
| 37 | R16 | `MODE15_N` | in | live | **strap: GND = native 15 kHz** (cabinet), open = 31 kHz. Internal pull-up; solder-jumper on shield, closed by default |
| 38 | P15 | `SPARE6` | — | spare | |
| 39 | R14 | `SYNC_CSYNC_N` | in | live | strap: GND = composite sync on `VID_HS`; open = separate H/V (**default — real MCR monitors take separate H/V on Video-8/9**) |
| 40 | P14 | `SYNC_VSOFF_N` | in | live | strap: GND = hold VS inactive (single-sync RGBS); open = normal |

Sanity check for layout review: 20 live signals + 3 straps + 8 reserved +
7 spare + 2 power = 40 exactly; every ball above matches spec §4a's
schematic-verified table, and every **live** pin matches what the current
bitstreams already drive (`bench_wiring.md`).

## 2. Power domains and level shifting (read this first)

**All logic on the shield runs at 3.3 V — the 74HC165s, the 74HC595s,
everything that touches a J10 pin. There are no level-shifter ICs
anywhere.** The board has exactly three voltage domains, and every
crossing between them is done by a part that is there for another reason
anyway:

| Domain | What lives in it | Crossing to/from |
|---|---|---|
| **3.3 V logic** (shield LDO from the buck's 5 V — J10 has no 3V3 pin) | shift registers, pull-ups, everything wired to J10 | is the FPGA's native level: direct connection |
| **5 V / cabinet harness** | switch loops (pulled to 5 V via 4.7 kΩ, switched to cabinet GND), monitor sync inputs | **inputs: the 74AHC165s themselves.** AHC inputs are rated to 5.5 V *independent of VCC*, so a 3.3 V-powered '165 legally takes the 5 V harness levels straight in — the shift register IS the level shifter. Each line gets a passive conditioning pad (below), nothing active. **sync out:** 74HCT244 powered at 5 V (its TTL thresholds accept 3.3 V swings — that is why HCT here) or a BC847 stage. **RGB out:** passive R2R ladder, no logic. |
| **12 V loads** | coin meters, lamps | ULN2803 Darlington array (3.3 V logic input is sufficient drive; built-in flyback diodes) |

Part-selection rules that follow:
- Input chain: **74AHC165** (TI SN74AHC165 / Nexperia 74AHC165) at
  VCC = 3.3 V. The load-bearing datasheet line is *"recommended input
  voltage up to 5.5 V regardless of VCC"* — verify it in the exact
  vendor/package chosen at order time. Thresholds at 3.3 V: VIH ≈ 2.3 V
  (5 V idle line: fine), VIL ≈ 1.0 V (closed switch: fine).
- **Plain 74HC165 will NOT work here** (inputs limited to VCC + 0.5 V —
  5 V in on a 3.3 V part is out of spec); 74HCT/74LS are 5 V-supply
  parts. The output '595 sees only 3.3 V signals, so 74HC595 or
  74AHC595 both work.
- The one deliberate HCT part is the 5 V sync buffer, chosen *because*
  of its TTL thresholds. The chain runs at 2 MHz — decades below any of
  these parts' limits.

**Why no optocouplers?** The earlier spec draft used TLP281-4s "for
isolation", but the shield's buck is non-isolated — cabinet ground and
logic ground are already common through the power path, so the optos
never provided galvanic isolation, only over-voltage protection. The
conditioning pad below provides that protection passively. (If a truly
isolated build is ever wanted, it needs an isolated supply first; the
opto variant is preserved in the spec's git history.)

## 3. Input chain — every switch in the cabinet on 3 pins

Seven 74HC165s daisy-chained, read through 3 header pins. `IN_LOAD_N`
snapshots **all 56 bits in the same instant**, which is what makes the
8-bit parallel spinner/trackball buses safe to serialize — no tearing, by
construction. A full scan at 2 MHz takes ~30 µs; the games poll their
inputs once per frame (16.7 ms), so the chain is ~500× faster than
anything the software can observe.

### 3a. Chain control lines ↔ J10 (bussed to all seven '165s)

| Signal | 74HC165 pin(s) | J10 pin | FPGA ball | Direction |
|---|---|---|---|---|
| `IN_CLK` | pin 2 (CP) on U1…U7 | 25 | AA21 | FPGA → chain |
| `IN_LOAD_N` | pin 1 (PL̄) on U1…U7 | 26 | AA20 | FPGA → chain |
| `IN_DATA` | pin 9 (QH) of **U7 only** | 27 | AB20 | chain → FPGA |
| cascade | U1.9 → U2.10, U2.9 → U3.10, … U6.9 → U7.10 | — | — | on-shield |
| tie-offs | pin 15 (CE̅) → GND, pin 10 (SER) of **U1** → GND, pin 7 (Q̄H) n/c, pin 16 → 3V3, pin 8 → GND | — | — | all devices |

Serial arrival order (RTL contract, not a PCB concern): after the load
pulse, bits arrive **U7 first, input H first** — U7.H, U7.G … U7.A, U6.H
… down to U1.A last.

### 3b. '165 inputs ↔ conditioning ↔ MCR harness, device by device

> **This section is the MCR-2 wiring example.** For a board meant to run
> the whole family (3-player Rampage, the mono/scroll connector remapping),
> allocate the chain by SSIO input port instead — see §6(a). The electrical
> pad and control lines below are unchanged either way.

'165 input pins: A=11, B=12, C=13, D=14, E=3, F=4, G=5, H=6. Each
harness line gets the same passive pad — this is the whole input stage:

    harness pin ──┬── 4.7 kΩ pull-up to +5 V (shield rail)
                  └── 1 kΩ series ──┬── 74AHC165 input
                                    ├── 10 nF to GND (RC ≈ 10 µs — the
                                    │   same line filtering the SSIO had)
                                    └── BAT54S clamp to +5 V / GND
                                        (survives a 12 V miswire: the
                                        fault drops across the 1 kΩ)

Idle = 5 V = high, pressed = low — the same polarity the original SSIO
saw, read by a 3.3 V part with 5.5 V-tolerant inputs. All eight bits of a
dial bus share identical pads, so RC skew between bits is nil and the
atomic '165 load strobe samples a coherent word.

**U1 — player 1 + coins**

| '165 input | pin | MCR harness | Function |
|---|---|---|---|
| A | 11 | J2-1 | P1 Up |
| B | 12 | J2-2 | P1 Down |
| C | 13 | J2-3 | P1 Left |
| D | 14 | J2-4 | P1 Right |
| E | 3 | J2-5 | P1 Button 1 |
| F | 4 | J2-6 | P1 Button 2 |
| G | 5 | J3-1 | Coin 1 |
| H | 6 | J3-2 | Coin 2 |

**U2 — system + P2 switches**

| '165 input | pin | MCR harness | Function |
|---|---|---|---|
| A | 11 | J3-3 | Start 1 |
| B | 12 | J3-4 | Start 2 |
| C | 13 | J3-5 | Tilt |
| D | 14 | J5-17 | P2 Left |
| E | 3 | J5-18 | P2 Right |
| F | 4 | J5-19 | P2 Button 1 (Tron cocktail fire — the FPGA also ORs this with SW1-8, spec §7a; no special wiring) |
| G | 5 | spare pad | tie the '165 input high via its pull-up |
| H | 6 | spare pad | " |

**U3 — Opt X: the 8-bit dial/spinner/trackball-X bus**

| '165 input | pin | MCR harness | Function |
|---|---|---|---|
| A | 11 | J4-1 | Opt X D0 |
| B | 12 | J4-2 | Opt X D1 |
| C | 13 | J4-3 | Opt X D2 |
| D | 14 | J4-4 | Opt X D3 |
| E | 3 | J4-5 | Opt X D4 |
| F | 4 | J4-6 | Opt X D5 |
| G | 5 | J4-7 | Opt X D6 |
| H | 6 | J4-9 | Opt X D7 (J4-8 is the connector key, J4-10 is GND) |

Used by: Tron aim dial, Kick spinner, Kroozr dial, Wacko trackball X,
DoT rotary, Spy Hunter steering (roadmap).

**U4 — Opt Y / P2 stick**

| '165 input | pin | MCR harness | Function |
|---|---|---|---|
| A | 11 | J5-1 | Opt Y D0 |
| B | 12 | J5-2 | Opt Y D1 |
| C | 13 | J5-3 | Opt Y D2 |
| D | 14 | J5-4 | Opt Y D3 |
| E | 3 | J5-5 | Opt Y D4 |
| F | 4 | J5-6 | Opt Y D5 |
| G | 5 | J5-15 | Opt Y D6 / P2 Up |
| H | 6 | J5-16 | Opt Y D7 / P2 Down |

Used by: Wacko trackball Y; P2 stick for Tapper/Timber (roadmap) and
cocktail play.

**U5 — J6 / SSIO IP4 aux port** (J6 pin IDs provisional — the matrix PDF
has no J6 sheet, cross-check a cabinet manual before crimping, `TODO.md`)

| '165 input | pin | MCR harness | Function |
|---|---|---|---|
| A…H | 11,12,13,14,3,4,5,6 | J6-1…J6-8 | IP4 D0…D7: Kroozr stick Y (**needed even upright**), Two Tigers P2 dial, Wacko cocktail aim, DoT aux (roadmap) |

**U6 / U7 — the DIP banks** (on-shield switches: no conditioning pads
needed, and their pull-ups go to 3V3, not 5 V — mixed levels are fine on
5.5 V-tolerant inputs)

| Device | '165 input A…H | Connects to | Function |
|---|---|---|---|
| U6 | pins 11,12,13,14,3,4,5,6 | SW1 positions 1…8, switch→GND, 4.7 kΩ pull-up to 3V3 | game option DIPs = the core's IP3 verbatim (spec §7a); closed = 0 |
| U7 | pins 11,12,13,14,3,4,5,6 | SW2 positions 1…8, same wiring | system DIPs: menu enable, video mode, … (spec §7a) |

## 4. Output chain — meters and lamps (2× 74HC595 = 16 bits)

**Populate two 74HC595s (U8, U9) from the start.** The original single '595
was sized for MCR-2 (2 coin meters + 2 start lamps); vendoring the MCR-3
family showed 8 bits is short: the **MCR3Mono board drives two SSIO output
ports, `output_5` and `output_6` (16 bits)**, and Spy Hunter adds a lamp
panel (`show_lamps`). Two '595s cover it on the same 4 pins (they daisy-
chain, `U8.QH' → U9.SER`); add a third later at zero pin cost. Outputs feed
ULN2803s (cabinet 12 V loads, flyback diodes in the ULN):

| Device.bit | Typical load | Notes |
|---|---|---|
| U8.QA/QB | Coin meter 1 / 2 | all games |
| U8.QC/QD | Start 1 / 2 lamp | |
| U8.QE–QH | player-3 start lamp, game lamps | Rampage is **3-player** |
| U9.QA–QH | `output_6` / Spy Hunter lamp panel | mono + scroll games |

The FPGA maps SSIO `output_4/5/6` (per game) onto these bits; wire the
cabinet's real loads to whichever bits a given game drives.

`OUT_EN_N` (pin 34) **must have a pull-up on the shield**: it holds every
output off from power-on until the gateware takes control — no coin-meter
clicks or lamp flashes during the ~1 s of FPGA configuration.

## 5. Video, audio, straps (live today)

- **DAC:** 3-bit R2R per gun — MSB 510 Ω, 1 kΩ, 2 kΩ (bench-proven values,
  `bench_wiring.md`) summed into the monitor's 75 Ω ≈ 1 Vp-p. Bit 0 of
  each gun is just an MSB copy for 4-bit Pmods — leave it unconnected or
  pad for a future 4th resistor.
- **Sync:** `VID_HS`/`VID_VS` are 3.3 V, negative-going. Buffer to 5 V TTL
  for the cabinet (BC847 stage or 74HCT244 at 5 V, spec §3). Real MCR
  monitors want **separate H and V** (Video conn pins 8/9) — leave the
  pin-39/40 straps open; they exist for OSSC/RetroTink-style RGBS gear.
- **15 kHz:** close the pin-37 solder jumper for a cabinet build. Open =
  31 kHz for bench VGA monitors. HDMI works in both modes regardless.
- **Audio:** PWM out; RC low-pass (~15 kHz corner) → LM386 on the 12 V
  rail → speaker (spec §3). Mono cabinets use `AUD_PWM_L`.
- **Status LEDs (pins 21–24):** route to 4 small LEDs via 1 kΩ. They are
  the case-closed diagnostics: calib steady + pix/27M blinking + ddr_rst
  off = video pipeline healthy.

## 6. Coverage across the WHOLE MCR family (reviewed after vendoring)

The header, pin budget, AHC-direct input stage and (now-16-bit) output
chain all hold up for every MCR family. But vendoring MCR-3/Scroll/Mono
surfaced three things the original MCR-2-era allocation missed — none break
the header, all are allocation/labeling fixes:

**(a) Allocate the input chain by SSIO input PORT, not by MCR-2 function.**
The cores read five bytes `input_0..input_4` (IP0–IP4) and each game maps
its own controls into them. Crucially, **different boards route the same IP
port to different cabinet connectors** — the SSIO board puts IP0/IP1 on J4,
IP2 on J5, IP4 on J6; the MCR3Mono board puts IP0/IP1 on J2, IP2 on J3,
IP4 on J4 (verified in MAME `mcr3.cpp`). So a universal shield should give
each IP port its **own '165 with a clean 8 bits**, wired from whatever
control that cabinet uses, and let the FPGA do the per-game mapping:

| '165 | Byte | Wire from the cabinet's… |
|---|---|---|
| U1 | IP0 | coins, starts, tilt, service, P1 button(s) |
| U2 | IP1 | P1 stick **or** the 8-bit dial/spinner (dial games) |
| U3 | IP2 | P2 stick / trackball-Y / gas pedal (per game) |
| U4 | IP4 | aux: **P3 stick (Rampage)**, P2 dial, Kroozr stick-Y, DoT aux |
| U6/U7 | IP3 | SW1 (game DIPs) / SW2 (system DIPs) |

This is simpler than the old 7-device hybrid (which split P1 across U1 and
coins, and left P2 one bit short) and it covers everything below. The §3b
tables above are the **MCR-2 wiring example**; re-label the screw terminals
by IP port for a universal build.

**(b) 3-player and multi-analog games are real.** Concretely:

| Game(s) | The demand | Covered by |
|---|---|---|
| Domino/Tron/Shollow/Wacko/Kroozr/2Tigers (MCR-2) | 1–2 players, dials, cocktail | U1–U4 (shipping) |
| Kick / Solar Fox (MCR-1) | spinner / stick | U2 |
| Tapper, Timber (MCR-3) | 2 players, 2-way sticks + buttons | U1–U3 |
| **Rampage (Mono)** | **3 players** (3× 8-way + 2 buttons) | IP1/IP2/IP4 = U2/U3/U4 |
| **Spy Hunter (Scroll)** | steering **+** gas (2 analog axes, muxed by an SSIO output bit) + 5 buttons + gear | both on the IP2 byte, alternated by `output_4`; buttons on IP0/IP1; lamps on the '595 chain |
| **Max RPM (Mono)** | **2 wheels + 2 pedals** (4 axes, muxed) | the IP1 byte, alternated by output bits |

The analog axes arrive as **8-bit digital** on their IP byte (the original
MCR control PCB does the pot→ADC conversion; the game time-multiplexes
several axes onto one byte using an SSIO *output* select bit). So the
shield's digital '165 reads them fine **from a cabinet that has that
control PCB**. A bare-potentiometer hookup would need an ADC the shield
does not provide — worth a silkscreen note, but out of scope for a
harness-in build.

**(c) J9 SDRAM is now mandatory, not optional.** Three of the five families
(all of MCR-3/Scroll/Mono) require the Tang SDRAM module in J9 for the
128–256 KB real-time sprite ROM. "Leave J9 clear" (§ ground rules) is a
hard requirement for a board meant to run the whole family, not just
future-proofing.

Bottom line: **the guide still makes sense — the 40-pin header, the
electrical design, and the chain architecture all scale to the full
family.** The updates are: allocate the input chain by IP port (above),
populate 2× '595 (§4), and treat J9 as reserved-mandatory.

## 7. Bring-up order for the board

1. Populate video DAC + sync buffer + audio + straps + LEDs only. Flash
   any current `bitstreams/console60k_*.fs` → full game on the cabinet
   monitor (15 kHz strap closed), sound, LEDs. No new gateware needed.
2. Populate optos + '165/'595 chains once the expander RTL lands
   (tracked in TODO.md; pins are frozen here, so no board spin).
3. USB pad and HDMI work throughout as the reference path.

## 8. Change control

- This table is the contract: `mcr2_console60k.cst`, the expander RTL, and
  `tools/generate_pcb.py` must follow it. If a pin must move, change THIS
  file first, in the same commit.
- Current CST already matches every **live** pin (they are today's bench
  assignments, deliberately). The **reserved** pins appear in the CST only
  when the expander RTL lands.

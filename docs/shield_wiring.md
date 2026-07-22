# MCR shield — connector footprints & chip wiring

Build companion to `shield_j10_pinout.md` (the FPGA-side header) and
`universal_mcr_shield_spec.md` (electrical spec). This is the **cabinet
side**: which physical connectors the harness plugs into, and how the
input/output/analog chips wire between those connectors and the J10 header.

Interface style is settled (spec §0): the **cabinet harness plugs into the
shield**; the FPGA maps every pin per game, so nothing is rewired. Rev A
targets the **SSIO-family connectors** (MCR-1/2 + SSIO MCR-3).

Pin functions below are from `docs/MCR_Master_Pinouts.pdf` (the master
matrix) — authoritative for what each pin does. Physical housing/pin-count
should be confirmed against a real MCR harness before ordering connectors.

---

## 1. Cabinet connectors (what the harness plugs into)

All MCR connectors are the **0.156" (3.96 mm) pitch** family (Molex
09-xx / .156 edge fingers). Present these on the shield edge, keyed, in
the standard MCR positions:

| Ref | Connector | Pins | Carries | Footprint (verify vs harness) |
|---|---|---:|---|---|
| **J2** | Player 1 controls | 13 | P1 stick + 2 buttons, GND | .156" 13-pin (1-row) header, key at the game's keyed pin |
| **J3** | Coin door / system | 5–6 | Coin1/2, Start1/2, Tilt | .156" 6-pin header |
| **J4** | Opt X (dial bus / analog) | 10 | 8-bit dial data **or** analog pots, key, GND | .156" 10-pin header; **also feeds the ADC — see §4** |
| **J5** | Opt Y / Player 2 | 19 | P2 controls, trackball-Y, P2 mux data | .156" 19-pin header |
| **Video** | RGB + sync | 9 | R, G, B (+ GNDs), HSync, VSync, key | .156" 9-pin header |
| **Audio** | speaker | 2 | speaker + / − | .156" 2-pin or screw terminal |
| **Power** | cabinet 12 V in | 2–3 | +12 V, GND (shield bucks to 5 V/3.3 V) | screw terminal or .156" |

Notes:
- **J1 / +5 V:** the shield generates its own 5 V/3.3 V from cabinet 12 V
  (spec §3). Do **not** take the cabinet's +5 V logic rail.
- **Key pins** (J4-8, Video-7) are the connector's mechanical key — leave
  the shield position blank/plugged to match.
- Grounds (J2-13, J4-10, Video-2/4/6) all tie to the shield star ground.

Pin-by-pin functions (from the master matrix), abbreviated to the standard
MCR function — the FPGA re-interprets per game:

```
J2 (P1):   1 Up   2 Down  3 Left  4 Right  5 Btn1  6 Btn2            13 GND
J3 (sys):  1 Coin1  2 Coin2  3 Start1  4 Start2  5 Tilt
J4 (OptX): 1..7 = Data D0..D6   8 Key   9 = Data D7   10 GND
J5 (OptY): 1..6 = P2mux/D0..D5  15 D6/P2Up  16 D7/P2Dn  17 P2Left
           18 P2Right  19 P2Btn1
Video:     1 Red  2 GND  3 Green  4 GND  5 Blue  6 GND  7 Key
           8 HSync(-)  9 VSync(-)
```

---

## 2. Input chain — harness → 74AHC165 → FPGA

Every switch/data line goes: **cabinet pin → passive pad → 74AHC165
parallel input**. The FPGA clocks the chain out on 3 J10 pins
(`IN_CLK`/`IN_LOAD_N`/`IN_DATA`). Allocate **one '165 per SSIO input port**
(spec/pinout §6a) so 3-player and remapped-connector games all fit.

### 2a. The per-line conditioning pad (identical on every input)

```
   cabinet pin ──┬───[ 4.7kΩ ]─── +5V        (pull-up: idle = high)
                 │
                 └───[ 1kΩ ]──┬────────── 74AHC165 input (A..H)
                              │
                    10nF ═════╪═════ GND      (RC ~10µs debounce/filter)
                              │
                    BAT54S ───┤          (clamp to +5V / GND: a 12V
                     (dual)   │           miswire drops across the 1kΩ)
```

74AHC165 runs at **3.3 V**; its inputs are 5.5 V-tolerant, so they take the
5 V harness levels directly (spec §2). Idle = 5 V = logic 1; a closed
switch pulls to GND = logic 0 — the same polarity the SSIO saw.

### 2b. Chain topology (7 devices, 3 FPGA pins)

```mermaid
flowchart LR
    subgraph FPGA["Tang 60K (J10)"]
      CLK["IN_CLK (pin25)"]
      LD["IN_LOAD_N (pin26)"]
      DAT["IN_DATA (pin27)"]
    end
    U1["U1 74AHC165\nIP0: coins/start/tilt/svc/btn"] -->|QH→SER| U2["U2 74AHC165\nIP1: P1 stick / dial"]
    U2 -->|QH→SER| U3["U3 74AHC165\nIP2: P2 / trackball-Y / gas"]
    U3 -->|QH→SER| U4["U4 74AHC165\nIP4: aux / P3 stick"]
    U4 -->|QH→SER| U6["U6 74AHC165\nSW1 game DIPs (IP3)"]
    U6 -->|QH→SER| U7["U7 74AHC165\nSW2 system DIPs"]
    CLK -->|CP, bussed to all| U1
    LD -->|PL̄, bussed to all| U1
    U7 -->|QH| DAT
```

`IN_LOAD_N` low pulse snapshots **all** '165 inputs at the same instant, so
the 8-bit dial/trackball buses can't tear. Control lines (`CP`, `PL̄`) bus
to every device; only the last device's `QH` returns on `IN_DATA`.

Per-'165 pin map (all devices identical): `CP`=pin2, `PL̄`=pin1,
`QH`=pin9, `SER`(cascade in)=pin10, `CE̅`=pin15→GND, `VCC`=pin16→3V3,
`GND`=pin8. Parallel inputs A..H = pins 11,12,13,14,3,4,5,6.

### 2c. Which harness pins land on which '165

| '165 | SSIO byte | Wire these harness pins to A..H |
|---|---|---|
| U1 | IP0 | J3-1 Coin1, J3-2 Coin2, J3-3 Start1, J3-4 Start2, J3-5 Tilt, J2-5 Btn1, (service), (spare) |
| U2 | IP1 | J2-1 Up, J2-2 Dn, J2-3 Lf, J2-4 Rt, J2-6 Btn2 **— or —** J4-1..7,9 (the 8-bit Opt X dial, dial games) |
| U3 | IP2 | J5-17 P2Lf, J5-18 P2Rt, J5-19 P2Btn1, J5-15 P2Up, J5-16 P2Dn **— or —** J5-1..6,15,16 (Opt Y bus) |
| U4 | IP4 | J6 aux / **P3 stick+buttons (Rampage)** / P2 dial |
| U6/U7 | IP3 | on-shield SW1 / SW2 DIP banks (no harness) |

The "**— or —**" rows are the same '165 serving a stick **or** a dial,
depending on the cabinet's control — the FPGA reads the byte and maps it per
game. A given cabinet wires one or the other into U2/U3.

---

## 3. Output chain — FPGA → 74HC595 → ULN2803 → loads

Two '595s (16 bits) on 4 J10 pins (`OUT_CLK`/`OUT_DATA`/`OUT_LATCH`/
`OUT_EN_N`), then a ULN2803 per '595 for the 12 V coin meters/lamps.

```mermaid
flowchart LR
    subgraph FPGA["Tang 60K (J10)"]
      OCK["OUT_CLK (pin28)"]
      OD["OUT_DATA (pin31)"]
      OL["OUT_LATCH (pin32)"]
      OE["OUT_EN_N (pin34)"]
    end
    OD --> U8["U8 74HC595"]
    U8 -->|QH'→SER| U9["U9 74HC595"]
    OCK -->|SRCLK, bussed| U8
    OL -->|RCLK, bussed| U8
    OE -->|OE̅, bussed + pull-up| U8
    U8 --> UA["ULN2803"] --> L1["Coin meters, Start lamps, P3 lamp"]
    U9 --> UB["ULN2803"] --> L2["output_6 / Spy Hunter lamp panel"]
```

- `OUT_EN_N` **must have a 10 kΩ pull-up to 3V3 on the shield** so all
  outputs stay off through FPGA configuration (no coin-meter clicks).
- ULN2803 has built-in flyback diodes — fine for inductive coin meters.
- Loads run off cabinet 12 V; the ULN sinks to GND.

Per-'595: `SER`=pin14, `SRCLK`=pin11, `RCLK`=pin12, `OE̅`=pin13,
`QH'`(cascade)=pin9, `QA..QH`=pins15,1..7, `VCC`=16→3V3, `GND`=8.

---

## 4. Analog controls — the ADC (Spy Hunter & Max RPM only)

**Which games need it:** exactly two, both later-phase:

| Game | Family | Pots | MAME device |
|---|---|---|---|
| **Spy Hunter** | MCR3Scroll | steering + gas (2, muxed) | on-board ADC0848/0844 |
| **Max RPM** | MCR3Mono | 2 wheels + 2 pedals (4) | ADC0844 |

**Every other MCR control is digital** — buttons/sticks are switches, and
the dials/spinners/trackballs (Tron, Kick, Kroozr, Wacko, Two Tigers, Discs
of Tron) are **optical encoders**, which the FPGA decodes with the existing
`spinner.sv` quadrature logic. No ADC for any of those.

Why an ADC is needed here and nowhere else: on the real hardware the
steering/gas **potentiometers' analog wiper voltage came into the game
board and was digitized by an on-board ADC0844** (MAME instantiates it in
the machine config, e.g. `ADC0844(config, m_maxrpm_adc)` with the pots on
its channels). Our shield replaces that board, so it must carry the ADC to
read the pots. The pot wires arrive on the **Opt X (J4) / Opt Y (J5)**
lines — the same physical pins a dial game would drive digitally.

### 4a. Put it on the board with a switch — yes, and here's how

Because a cabinet is *one* game, and the analog pins overlap the digital
Opt X/Opt Y pins, route those lines to **either** the '165 (digital) **or**
the ADC (analog), selected per cabinet:

```mermaid
flowchart LR
    J4["J4 / J5 data lines\n(dial data OR pot wiper)"]
    JMP{"MODE jumper\nper channel"}
    P165["→ 74AHC165 pad\n(digital dial games)"]
    ADC["ADC (SPI)\npots → 8-bit"]
    J4 --> JMP
    JMP -->|DIGITAL| P165
    JMP -->|ANALOG| ADC
    ADC -->|SPI: SCLK/MOSI/MISO/CS on\n3 spare J10 pins + 1| FPGA["Tang 60K"]
    P165 --> FPGA
```

Recommended parts and wiring:
- **ADC: a modern SPI ADC — ADS7830 (8-ch, I²C) or MCP3208 (8-ch, SPI),
  populate-optional.** (You *can* use a real ADC0844 to match, but a modern
  SPI/I²C part is far easier to talk to from the FPGA and needs no special
  timing.) 8 channels covers Max RPM's 4 and Spy Hunter's 2 with room.
- **Analog reference / conditioning:** each pot wiper → RC (series ~1 kΩ,
  100 nF to GND) → ADC channel; pot ends to the shield's clean 5 V and GND.
- **MODE jumpers:** a small 2-pin jumper (or a 2-pole DIP) per analog
  channel selects that harness line to the '165 pad or the ADC input. Set
  once at install ("this cabinet is Spy Hunter → Opt X = ANALOG").
- **FPGA side:** the ADC's SPI/I²C lands on **spare J10 pins** (9, 19, 20,
  29/30, 38 are free) — no impact on the input/output chains. The core reads
  the ADC channels and feeds the digitized value into the analog input port;
  the running game_id tells it whether to use the ADC or the '165 byte.

Simplest build: **leave the ADC footprint unpopulated for the common
(digital) cabinets**, and populate it + set the MODE jumpers only when a
shield goes into a Spy Hunter or Max RPM cabinet. Both are Phase D/E games,
so the ADC can come after the first analog core is running.

An FPGA-controlled analog mux (74HC4053) could auto-switch digital/analog by
game_id instead of a manual jumper — slicker, but since a cabinet is one
game the jumper is simpler and cheaper. Offered as an option, not the base.

---

## 5. Video DAC & sync buffer (live today)

- **RGB:** 3-bit R2R per gun into Video-1/3/5 — MSB 510 Ω, then 1 kΩ, 2 kΩ,
  summed into the monitor's 75 Ω ≈ 1 Vp-p (bench-proven, `bench_wiring.md`).
  Drive from J10 `VID_R/G/B` (§ pinout). Video-2/4/6 = GND.
- **Sync:** J10 `VID_HS`/`VID_VS` (3.3 V, negative) → 74HCT244 at 5 V (TTL
  thresholds accept 3.3 V in) → Video-8/9. Real MCR monitors take separate
  H/V; the pin-39/40 straps offer csync for OSSC/RetroTink gear.
- **15 kHz:** close the J10 pin-37 solder jumper for cabinet timing.

---

## 6. Power

Cabinet **+12 V → screw terminal → buck (5 V, ≥1.5 A) → LDO (3.3 V)**.
5 V feeds the AHC/HC logic rails and the input pull-ups; 3.3 V is the logic
VCC and the FPGA level. Audio amp (LM386) runs off the 12 V rail. Do not
back-feed the cabinet 5 V (spec §6.1).

---

## 7. BOM summary (control interface)

| Qty | Part | Role |
|---:|---|---|
| 7 | 74AHC165 | input chain (5 V-tolerant, 3.3 V VCC) |
| 2 | 74HC595 | output chain |
| 2 | ULN2803 | 12 V coin-meter / lamp drivers |
| 1 | 74HCT244 | 5 V sync buffer |
| 1 | ADS7830 / MCP3208 (opt.) | analog pots (Spy Hunter / Max RPM) |
| — | ADC MODE jumpers (opt.) | route Opt X/Y to '165 or ADC per cabinet |
| — | R2R resistors (9), sync caps, BAT54S clamps, pull-ups | passives |
| 1 | buck + LDO | 12 V → 5 V → 3.3 V |
| — | .156" MCR connectors (J2/J3/J4/J5/Video/Audio) | harness interface |

Everything except the ADC block is required for every cabinet; the ADC
block is populate-if-analog.

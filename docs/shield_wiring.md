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

**Two pitches, and only one is ours.** MCR used both .156" and .100"/ribbon
connectors, but they served different jobs:

- **.100" (2.54 mm) / ribbon — board-to-board interconnect, NOT ours.** The
  original MCR boardset (CPU + video-gen + SSIO/sound) was stacked and
  interconnected with small-pitch ribbon/SIPP connectors (the MCR FAQ:
  "very early MCR games used SIPP-style sockets for the J1 and J2 connectors
  with solid core wire ribbon cables interconnecting the boards"). **The
  shield replaces the entire boardset, so those interconnects simply don't
  exist for us** — there are no separate boards to link.
- **.156" (3.96 mm) — the cabinet harness, which is what the shield
  presents.** Player controls, coins, video, power, audio: the connectors
  the cabinet's own wiring plugs into.

So for the shield, target the **.156" cabinet-harness connectors** below.
(Pitch on a couple of individual connectors — the video connector
especially — is worth confirming against a real harness or the specific
game's schematic before ordering; see the caveat after the table.)

Present these on the shield edge, keyed, in the standard MCR positions:

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
- **Pitch caveat — verify before ordering.** The controls/coin/power
  connectors are .156"; the **video connector's pitch (.156 vs .100) is the
  one to double-check** against the target game's harness, as it varied. The
  dial games' 8-bit Opt-X bus arrives on J4 as **parallel digital**, not
  raw quadrature — the cabinet's *Angle Encoder Board* converts the knob's
  quadrature to parallel position data before J4/J6 (MCR FAQ). So the '165
  reads it directly, **provided the cabinet still has its Angle Encoder
  Board**; a bare encoder would need quadrature decode in the FPGA
  (`spinner.sv`) instead.

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
    U1["U1 74AHC165<br/>IP0: coins/start/tilt/svc/btn"] -->|QH→SER| U2["U2 74AHC165<br/>IP1: P1 stick / dial"]
    U2 -->|QH→SER| U3["U3 74AHC165<br/>IP2: P2 / trackball-Y / gas"]
    U3 -->|QH→SER| U4["U4 74AHC165<br/>IP4: aux / P3 stick"]
    U4 -->|QH→SER| U6["U6 74AHC165<br/>SW1 game DIPs (IP3)"]
    U6 -->|QH→SER| U7["U7 74AHC165<br/>SW2 system DIPs"]
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
    J4["J4 / J5 data lines<br/>(dial data OR pot wiper)"]
    JMP{"MODE jumper<br/>per channel"}
    P165["→ 74AHC165 pad<br/>(digital dial games)"]
    ADC["ADC (SPI)<br/>pots → 8-bit"]
    J4 --> JMP
    JMP -->|DIGITAL| P165
    JMP -->|ANALOG| ADC
    ADC -->|SPI: SCLK/MOSI/MISO/CS on<br/>3 spare J10 pins + 1| FPGA["Tang 60K"]
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

### 4b. FPGA-driven mode switch (recommended — no jumper)

The manual jumper works, but the FPGA can drive the digital/analog switch
itself, which keeps the "select the game, nothing else" promise for the
analog cabinets too. It's actually cleaner **and reuses hardware already on
the shield**:

```mermaid
flowchart LR
    GID["core game_id<br/>(from OSD)"] --> MB["MODE bit<br/>= analog for<br/>Spy Hunter / Max RPM"]
    MB -->|rides a spare<br/>74HC595 output bit| SW["74HC4053 analog switch<br/>(per analog channel)"]
    J["J4/J5 analog-capable pin"] --> SW
    SW -->|MODE=digital| PAD["4.7k pull-up + '165 pad"]
    SW -->|MODE=analog| ADCIN["ADC channel (clean)"]
```

How it works, step by step:

1. **The FPGA already knows the running game** (`game_id` from the OSD). It
   derives one **MODE** bit — high only for Spy Hunter / Max RPM. MODE is
   static per game (set when the game loads, never changes mid-play).
2. **MODE rides a spare bit of the existing 74HC595 output chain** — no new
   J10 pin. The '595s are already on the board for lamps/meters; one unused
   output bit becomes the mode line.
3. That bit drives a **74HC4053-class analog switch** on each analog-capable
   channel (≈4: Max RPM's worst case). In **digital** mode the pin routes to
   its normal pull-up + '165 pad; in **analog** mode the switch **lifts the
   pull-up** and routes the pin straight to the ADC channel. Lifting the
   pull-up is the whole point — a 4.7 kΩ pull-up to 5 V would offset a pot's
   reading, so it must be out of circuit for analog.
4. In analog mode the '165 still *sees* that pin and clocks in some
   arbitrary 0/1 — **harmless, the FPGA ignores those bits for that game.**

**Bonus you get for free:** the *channel* muxing (steering vs gas; which of
Max RPM's four axes) was **already game-driven on the original hardware** —
the game wrote the ADC0844's channel select and RD/WR strobes through its
SSIO output ports (`mcr3.cpp`: Max RPM latches the mux on `output`, Spy
Hunter toggles the ADC via an output bit). Our core reproduces those output
ports, so if you wire the core's `output_4/5/6` to the ADC's channel-select/
strobe lines, the game sequences the ADC exactly as it did in 1984 — no
extra logic. The only *new* thing is the per-cabinet digital-vs-analog pin
routing (MODE), because a universal shield serves both a dial cabinet and a
pot cabinet on the same pins, whereas the original Spy Hunter board was
always analog.

**Recommendation:** design for the FPGA-driven switch (MODE on a '595 bit +
74HC4053s), and keep a **manual override jumper in parallel** as a
populate-option fallback — cheap insurance while the analog path is
unproven. Cost over the jumper-only build: ~one 74HC4053 (maybe two) and a
few traces; payoff: the analog cabinets are as plug-and-play as the rest.

**One detail to lock down at Phase D:** exactly which harness pins carry the
Spy Hunter / Max RPM pot wipers (the master matrix normalizes them onto the
"Opt X D0–D7" label, but 2 pots ≠ 8 data bits, so the physical wiper pins
need confirming against those games' schematics). Finalize the analog
channel count and pin map when the first analog core (Spy Hunter) is brought
up — until then, route the ADC + switch footprints for the worst case (4
channels) and leave them unpopulated.

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
| 1–2 | 74HC4053 (opt.) | FPGA-driven digital/analog mode switch (§4b); MODE rides a spare '595 bit |
| — | manual MODE jumper (opt., fallback) | override the FPGA switch per cabinet |
| — | R2R resistors (9), sync caps, BAT54S clamps, pull-ups | passives |
| 1 | buck + LDO | 12 V → 5 V → 3.3 V |
| — | .156" MCR connectors (J2/J3/J4/J5/Video/Audio) | harness interface |

Everything except the ADC block is required for every cabinet; the ADC
block is populate-if-analog.

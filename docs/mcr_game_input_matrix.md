# MCR Game Input Matrix (machine-readable)

Transcribed from `docs/MCR_Master_Pinouts.pdf` ("Ultimate MCR Master Pinout
Matrix"). This is the source of truth for what each cabinet connector pin
does per game. The physical wiring is identical across MCR-1/2/3 — only the
in-game meaning changes, so all game-specific mapping is done in the FPGA
top-level, never on the shield PCB.

Legend: `-` = N/C for that game. "No J5" (MCR-1 and most MCR-2 cabinets have
no J5 harness) is also shown as `-`.

Games: SF=Solar Fox (MCR-1), KK=Kick/Kickman (MCR-1), TR=Tron (MCR-2),
SH=Satan's Hollow (MCR-2), KZ=Kozmik Krooz'r (MCR-2), WA=Wacko (MCR-2),
DM=Domino Man (MCR-2), TA=Tapper (MCR-3), JO=Journey (MCR-3), TI=Timber
(MCR-3), DT=Discs of Tron (MCR-3), SY=Spy Hunter (MCR-3), CR=Crater Raider
(MCR-3).

## J2 — Player 1 controls

| Pin | Std function | SF | KK | TR | SH | KZ | WA | DM | TA | JO | TI | DT | SY | CR |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| J2-1 | P1 Up | P1 Up | - | P1 Up | **P1 Left** | - | P1 Up | P1 Up | P1 Up | P1 Up | P1 Up | P1 Up | Machine Gun | - |
| J2-2 | P1 Down | P1 Down | - | P1 Down | **P1 Right** | - | P1 Down | P1 Down | P1 Down | P1 Down | P1 Down | P1 Down | Missiles | - |
| J2-3 | P1 Left | P1 Left | - | P1 Left | - | - | P1 Left | P1 Left | P1 Left | P1 Left | P1 Left | P1 Left | Oil Slick | P1 Left |
| J2-4 | P1 Right | P1 Right | - | P1 Right | - | - | P1 Right | P1 Right | P1 Right | P1 Right | P1 Right | P1 Right | Smoke Screen | P1 Right |
| J2-5 | P1 Button 1 | Fire/Turbo | Kick | Fire (Trigger) | Fire (Trigger) | Fire | - | Place/Strike | Pour/Serve | Fire | - | Fire (Trigger) | Weapons Van | Fire |
| J2-6 | P1 Button 2 | - | Catch | - | Shield | - | - | - | - | - | - | Deflect | - | Shield |
| J2-13 | Ground | GND | GND | GND | GND | GND | GND | GND | GND | GND | GND | GND | GND | GND |

## J3 — System & coins (identical across all games)

| Pin | Function | Notes |
|---|---|---|
| J3-1 | Coin 1 | all games |
| J3-2 | Coin 2 | all games |
| J3-3 | Start 1 | all games |
| J3-4 | Start 2 | all games except Spy Hunter (N/C — 1-player game) |
| J3-5 | Tilt | all games |

## J4 — Opt X / 8-bit parallel dial data

Wiring is identical for every game: J4-1..J4-7 = data bits 0–6, J4-8 = key,
J4-9 = data bit 7, J4-10 = ground. Per-game meaning of the 8-bit bus:

| Game | J4 bus meaning |
|---|---|
| Solar Fox, Satan's Hollow, Domino Man, Tapper, Journey, Timber, Crater Raider | Data Bit 0–7 (standard/unused bus) |
| Kick/Kickman | Spinner X (D0–D7) |
| Tron | Opt/Main spinner (D0–D7) |
| Kozmik Krooz'r | Spinner X (D0–D7) |
| Wacko | Trackball X-Axis (D0–D7) |
| Discs of Tron | Rotary aim (D0–D7) |
| Spy Hunter | Steering/Gas (D0–D7) |

## J5 — Opt Y / trackball / Player 2 controls

| Pin | Std function | WA | TA | TI | DT | others |
|---|---|---|---|---|---|---|
| J5-1..J5-6 | P2 Mux / Data Bit 0–5 (Opt Y) | Trackball Y (D0–D5) | - | - | - | - |
| J5-15 | P2 Up / Data Bit 6 | Trackball Y (D6) | P2 Up | P2 Up | Aim Up | - |
| J5-16 | P2 Down / Data Bit 7 | Trackball Y (D7) | P2 Down | P2 Down | Aim Down | - |
| J5-17 | P2 Left | - | P2 Left | P2 Left | - | - |
| J5-18 | P2 Right | - | P2 Right | P2 Right | - | - |
| J5-19 | P2 Button 1 | - | P2 Pour | - | - | - |

## Video connector (identical across all games)

| Pin | Function |
|---|---|
| Video-1 | Red |
| Video-2 | Video GND |
| Video-3 | Green |
| Video-4 | Video GND |
| Video-5 | Blue |
| Video-6 | Video GND |
| Video-7 | Key |
| Video-8 | H-Sync (−) |
| Video-9 | V-Sync (−) |

## From connector pins to SSIO input ports (FPGA-internal)

The connector matrix above is cabinet wiring. The mapping of those switches
into the SSIO's `input_0..input_4` byte ports is per-game and must be taken
from MAME (`src/mame/midway/mcr.cpp`, `INPUT_PORTS_START(<game>)`); the
matrix cannot tell you bit positions. Verified examples:

- **Domino Man** — IP0 = {test, service1, tilt, **Button1**, start2, start1,
  coin2, coin1}; IP1 = {4'unused, down, up, right, left} (4-way);
  IP3 DIP upright default = `0x3E` (0xFF selects cocktail!).
- **Satan's Hollow** — IP0 = {service, x, tilt, x, start2, start1, coin2,
  coin1}; IP1 = {P2 fire, P2 shield, P2 right, P2 left, fire, shield,
  right, left}.
- **Tron** — IP0 = standard {test, service1, tilt, TRIGGER, start2, start1,
  coin2, coin1}; IP1 = 8-bit absolute aim dial (PORT_REVERSE); IP2 = P1
  8-way joystick [3:0] (+P2 cocktail [7:4]); IP3 DIP upright default =
  `0x80` (bit7 is the cocktail trigger input, idle high); IP4 = cocktail
  dial.
- **Wacko** — IP1 = trackball X, IP2 = trackball Y (free-running counters);
  IP4 = 4-way aim joystick {bit3 up, bit2 down, bit1 left, bit0 right};
  IP0 standard but with no Button 1. The SSIO output port 4 bit 0 muxes
  IP1/IP2 to the *cocktail* player's trackball only, so upright play needs
  no mux support — which is why this runs without exposing SSIO outputs.
- **Kozmik Kroozr** — IP1 packs the cockpit spinner unusually: the SSIO
  custom read returns `((dial & 0x80) >> 1) | ((dial & 0x70) >> 4)`, i.e.
  **bit 6 = dial[7], bits 2:0 = dial[6:4], both ACTIVE HIGH**; bit 7 is
  Button 2 (active low) and bits 5:3 are cockpit sensors. IP2 = analogue
  stick X, IP4 = analogue stick Y, both `0x30..0x98` centred on `0x64`.
- **Two Tigers** — use the **Tron-conversion set (`twotigerc`)**: IP1 = P1
  dial, IP4 = P2 dial, IP2[3:0] = the four fire buttons, IP0 bit 4 =
  "Dogfight Start". The *dedicated* set (`twotiger`) also needs a video-RAM
  address remap at 0xE800 that this core does not implement.

### MCR-1 games (core src/rtl/mcr1.vhd, board mcr1_console60k)

Verified against the MiSTer Arcade-MCR1 top (which matches MAME mcr.cpp).
All inputs active low; input_3 = the game-option DIP byte.

- **Kick / Kickman** — IP0 = {service, x, x, **kick**(bit4), start2, start1,
  x, coin1}; IP1 = {4'unused, **spinner[3:0]**} (kicker angle, a 4-bit
  absolute value — driven from d-pad L/R through `spinner.sv`, low nibble).
  IP2/IP4 unused. Runs on a rotated monitor (ORIENTATION_SWAP_XY).
- **Solar Fox** — IP0 = {service, x, x, **fire_a**(bit4), **fire_b**(bit3),
  **fire_b**(bit2), x, coin1}; IP1 = {up,down,left,right, up,down,left,right}
  (the 4-way stick mirrored into both nibbles); IP2 = {7'x, **fire_a**(bit0)}.
  ROT90^FLIP_Y.

DIP note: input_3 is a 0xFF placeholder for both (all option switches off)
pending a MAME default cross-check on hardware.

Method for new games: `awk '/INPUT_PORTS_START\( <game> \)/,/INPUT_PORTS_END/'
mcr.cpp` and read the `PORT_BIT` masks. All inputs are active low.

## Where the DIP switches physically live (and connector-number decoding)

Verified against MAME 0.265 (`mcr.cpp` + `mcr3.cpp`): **every SSIO-based MCR
game — all of MCR-1, MCR-2, and MCR-3 — uses the identical input scheme.**
The DIPs never moved between hardware generations:

| SSIO port | Physical location (MAME/schematic comments) | Function |
|---|---|---|
| IP0 | SSIO connector **J4 pins 1–8** | coins, starts, button 1, tilt, service |
| IP1 | SSIO connector **J4 pins 10–13, 15–18** | dial/joystick/trackball-X (per game) |
| IP2 | SSIO connector **J5 pins 1–8** | joystick/trackball-Y/P2 (per game) |
| IP3 | **DIP bank at board location B3 — on the SSIO board, NOT a connector** | game options |
| IP4 | SSIO connector **J6 pins 1–8** | second dial / aux (per game) |

Answers to the obvious questions:

- **Did the DIPs move around per game/generation? No.** One bank, location
  B3 on the Super Sound I/O board, read as IP3, on every SSIO game from
  Kick (1981) through Discs of Tron (1983). Physically a 10-position bank;
  8 positions reach IP3 (Tron's manual: 9 unused, 10 = freeze).
- **Do the DIPs plug into a connector / get unplugged for a fire button or
  spinner? No.** The DIPs are switches mounted on the board; buttons and
  spinners arrive on the J4/J5/J6 harness connectors — electrically separate
  lines. Nothing is ever unplugged.
- **Then how does Tron put a cocktail fire button "in" IP3 bit 7?** The
  harness wire and DIP position 8 are two contacts on the *same* active-low
  input line, in parallel. The manual's convention: leave SW1-8 OFF
  (open) so the button can pull the line. Our shield replicates exactly
  this: the FPGA ORs the SW1 bit with the harness line — leave the switch
  off, the button works; leave it on, the input is held active, which is
  precisely what the original hardware would do too.
- **There is a SECOND DIP bank** most people never touch: 6 switches on the
  SSIO read by the *sound* Z80 at 0xF000 (MAME's `ssio:DIP` port). Every
  game we've extracted leaves it unused (0xFF); it is sound-board config,
  not game options. We model it as constant 0xFF.

**Connector-numbering caution:** the tables at the top of this file (from
the master pinout PDF) group pins by *cabinet function* using J2/J3/J4/J5
labels that do **not** match the SSIO board's own J4/J5/J6 numbering above
— e.g. the PDF's "J3 coin door" pins land on SSIO J4 1-8 (IP0). Treat the
PDF's function names as truth and its J-labels as this project's harness
grouping; when reading MAME or original schematics, use the SSIO numbers.

## Known gaps (not covered by the matrix PDF)

- **J6** — MAME lists `ssio:IP4` as "J6 1-8" (auxiliary inputs); the matrix
  has no J6 sheet. Unused by the games above.
- **Outputs** — coin meters / lamps driven by SSIO output ports are not in
  the matrix; original cabinets wire them via J3-area harness. Deferred.

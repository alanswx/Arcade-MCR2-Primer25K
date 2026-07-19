# TODO / open issues

Single list of known gaps. Detail lives in the linked docs; this is the
index so nothing hides in a §6 somewhere. Roughly ordered by "blocks the
next real milestone" within each section.

---

## Cocktail mode — unaddressed across every game

**Everything currently assumes an upright cabinet.** This is not one switch;
it touches four separate things, and each game does it differently:

1. **Cabinet DIP is hardcoded upright.** `input_3` is a constant per game in
   `mcr2_console60k_top.sv` (Domino `0x3E` — note `0xFF` would select
   *cocktail*; Tron `0x80`). Nothing lets an operator choose. SW2-3 in the
   shield spec is reserved for this but unimplemented.
2. **Player-2 inputs are tied off.** Cocktail play needs the second player's
   controls, which live in different ports per game and are currently
   constants: Tron's cocktail joystick (IP2 upper nibble), Satan's Hollow
   (IP1 upper nibble), Two Tigers' P2 dial (IP4, tied to 0), Wacko's
   `IP1.ALT`/`IP2.ALT` trackball.
3. **Wacko's trackball mux is not implemented.** SSIO output port 4 bit 0
   selects P1 vs cocktail-P2 trackball. `mcr_sound_board.vhd` *does* expose
   `output_4`, but `mcr2.vhd` never brings it out to the entity — so this
   needs a (small) core port addition before cocktail Wacko can work. Upright
   play is unaffected, which is why it works today.
4. **Screen flip is unverified.** Cocktail cabinets rotate the image 180° for
   player 2. Need to establish whether the core implements flip at all, how
   it is triggered, and how it interacts with the DDR3 framebuffer capture
   (which samples the core's raster directly).

Also needed for real two-player use: a **second USB pad** on port 2
(usb2_dp M15 / usb2_dn M16 — pins verified, unused).

### How the cabinet setting actually reaches the core (two layers)

`input_3` **is** the original board's DIP bank (the switches at B3), read by
the SSIO as input port 3 — an internal core signal, not a pin. Our shield
replaces that board, so the FPGA has to supply those bits:

    SW2-3 (switch on the shield)
      -> 74HC165 chain -> 3 FPGA pins     (switch reaches the FPGA)
      -> per-game bit placement
      -> input_3 bit N -> core SSIO       (FPGA reaches the core)

So the cocktail switch both runs through the 165 *and* lands in `input_3`;
they are different layers. Neither costs additional pins.

**The bit position is different per game** (verified against MAME):

| Game | Cabinet bit in IP3 |
|---|---|
| Tron, Satan's Hollow | bit 1 (0x02) |
| Domino Man, Wacko, Kozmik Kroozr | bit 6 (0x40) |
| Two Tigers (conversion set) | none — IP3 unused entirely |

**`input_3` is not purely DIP switches.** Tron puts the *cocktail player's
fire button* on IP3 bit 7 (`PORT_BIT(0x80, ..., IPT_BUTTON1) PORT_COCKTAIL`),
so that port mixes config switches with a live cabinet input. Open question:
the master pinout matrix lists Tron as having **no J5**, so where a cocktail
Tron's P2 fire button arrives on the harness is undocumented — needs a
cocktail cabinet manual or real hardware. (J5-19 "P2 Button 1" is pinned and
is the obvious candidate, but that is a guess.)

**Other pin impact:** cocktail P2 controls for Tron/Domino arrive on SSIO
IP2 = J5 1-8, and §4b already pins all 11 J5 lines. **The one real gap is
IP4 / J6, which is not pinned at all** — see the Shield PCB section.

---

## Hardware bring-up (untested on the board)

- **SD ROM loader has never run on hardware.** Verified only in simulation
  against a card model (`make -C sim`). The card image is built but not yet
  burned. Beacon field `L<hex>` = {sd_ready, sd_err, done, error}.
- **Left-edge pixel overlap** on HDMI is still unresolved. Select + D-pad
  Right/Left tunes `cap_delay` live; one step is <2 screen pixels, so it
  takes 10–15 taps to see. Read the value from the beacon's `d<hex>` field,
  then hardcode it as `CAP_DELAY_DEFAULT`.
- **PmodVGA in the PMOD sockets is unproven.** Four strap combinations on
  J10-39/40 resolve row/socket orientation; also note the module is *not*
  passive — its SN74ALVC245 buffers need **3.3 V on VCC** (never 5 V).
  The J10 jumper route (or a DE-15 breakout + 9 resistors) avoids the
  ambiguity entirely.
- **New games' controls are derived, not played.** Trackball/analogue-stick
  sensitivity on a d-pad is guesswork — Kroozr's stick ramp rate especially.
  Tron's aim direction may need reversing (MAME marks the dial PORT_REVERSE).
- **Two Tigers has +0.08 ns setup slack** — met, but the tightest of the six.
  Suspect timing first if that game alone misbehaves.

---

## Multi-game / product

- **`game_slot` is hardwired to 0.** Slot selection needs the 74HC165 DIP
  reader (`docs/universal_mcr_shield_spec.md` §7b, J10 pins 20/31/32).
  Until then, changing games means rebuilding the pack in a different order.
- **No menu/OSD** (Phase B). The framebuffer has an overlay path; SW2-1 is
  reserved for menu-enable.
- **No multiboot selector** for switching MCR family cores (2.5 MB per core,
  so all three fit well under 8 MB of flash).
- **Fallback behaviour is minimal.** Loader failure currently just falls back
  to the baked ROMs; the shield spec requires a visible status code (LED)
  so a field failure is diagnosable without a laptop.

## Shield PCB

- **5 V delivery route unverified** — J10 pin 11 exposes +5 V but sits behind
  the dock's OR-ing/OVP chain; do not back-feed it until traced. USB-C is the
  known-good path.
- **J6 / SSIO IP4 is not pinned, and it is not just a cocktail concern.**
  IP4 carries: Wacko's cocktail aim joystick, Two Tigers' player-2 dial, and
  **Kozmik Kroozr's analogue stick Y axis — which is needed in upright play
  too**. The 8 reserved J10 pins can cover it, but the allocation has not
  been made and the master pinout PDF has no J6 sheet, so J6's cabinet
  wiring must be established before routing rev A.
- **Lamp / coin-meter outputs** unsurveyed (share those 8 reserved pins).
  Outputs need driver transistors, not optos.
- **`tools/generate_pcb.py` is not synced** to the §4b net table, and still
  assumes generic 2×20 headers; J9 must stay clear for the SDRAM module.
- **138K variant**: header nets are dock-level but the net→ball map is
  SOM-specific; re-extract before targeting it.

## Cores / ports

- **MCR-1** (Kick, Solar Fox): small next core, shares SSIO + video generator.
- **MCR-3** (Tapper, Timber, Discs of Tron, Rampage, Spy Hunter, …): needs
  external ROM storage (SDRAM module on J9) plus extra sound boards
  (Squawk & Talk, Turbo Cheap Squeak); one dual-CPU title. All ROMs are
  already in `roms/`.
- **Tang Primer 25K project is stale**: still the line-buffer video path and
  a Satan's Hollow input map. Fine as-is, but it no longer matches the 60K.
- **Tang Console 138K project is stale**: pre-framebuffer architecture.

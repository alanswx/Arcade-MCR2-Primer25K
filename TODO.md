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
IP2 = J5 1-8, and IP4 / J6 is covered too — every harness input rides the
shield's 74HC165 chain (`docs/shield_j10_pinout.md`), so no per-line pin
budget exists anymore. See the Shield PCB section.

---

## Hardware bring-up (untested on the board)

- ~~SD ROM loader has never run on hardware~~ **RESOLVED 2026-07-21**: pack
  written to the card with `tools/write_rompack.py` (lands in the gap
  before the card's partition, filesystem untouched) and games load from
  the OSD on hardware. The reject-foreign-card path was proven earlier
  (beacon `L09`).
- ~~HDMI black screen~~ **RESOLVED 2026-07-20** after a long hunt. HDMI now
  works: 720p from the DDR3 framebuffer, game + border verified on hardware.
  Root causes, in the order found (each invisible to the error log):
  1. video reset gated on ROM loading (fixed: video resets from power-on only)
  2. IDE `Place_Option 0` vs build.tcl's 2 (DDR3 never trained on IDE builds)
  3. **gbatang's cross-PLL serializer clocking** — pixel clock from the DDR3
     controller, serial clock from a second PLL; OSER10 phase left to routing
     luck. Restructured to NESTang's single chain (27→PLL→371.25→CLKDIV/5)
     with a shadow-raster + async-FIFO bridge into the scanout domain.
  4. **Verilog use-before-declaration** — Gowin makes an implicit 1-bit wire
     with only a warning; the encoder's rgb input was one floating bit and
     the pixel FIFO was swept. Post-build check #4 in CLAUDE.md now guards
     this ("Undeclared symbol" grep must be empty).
  Diagnostic assets that earned their keep, kept in the repo: the UART
  beacon, `diag/hdmi_selftest` (dvi_tx 640x480), `diag/fb_selftest`
  (framebuffer alone), `diag/nes_video_selftest` (NESTang clocking, the
  decisive one). Verified only in simulation
  against a card model (`make -C sim`). The card image is built but not yet
  burned. Beacon `L` low nibble = {sd_ready, sd_err, done, error}; high nibble low 2 bits = USB device type (3 = gamepad).
- **Left-edge pixel overlap.** Root cause is the core's ~13-pixel RGB-vs-hcnt
  pipeline lag. HDMI compensates in the capture window; the analog path did
  not compensate at all until 2026-07 (the previous line's tail leaked into
  the first ~13 visible pixels). Both paths now share the live-tunable
  `cap_delay` — Select + D-pad Right/Left, value in the beacon as `d<hex>`.
  **Still to do: confirm on hardware and hardcode the winning value as
  `CAP_DELAY_DEFAULT`.** One step is <2 screen pixels on HDMI, so it takes
  10–15 taps to see there; it should be far more obvious on analog.
- **Analog framing on a desk LCD is imperfect and expected.** The core emits
  634 pixels/line at 20 MHz; an LCD locks to it (31.55 kHz ≈ VGA's 31.47 kHz)
  but then samples ~800 pixels at 25.175 MHz across our line, stretching
  ~1.26× and mis-positioning active video. Use the monitor's Auto Adjust.
  A real 15 kHz arcade monitor has no sampling window and does not care, so
  this does not affect cabinet use — and fixing it for LCDs would mean
  putting a line buffer/scaler back into the analog path, which is exactly
  what keeps that path shimmer-free. Not worth it.
- **PmodVGA in the PMOD sockets is unproven.** Four strap combinations on
  J10-39/40 resolve row/socket orientation; also note the module is *not*
  passive — its SN74ALVC245 buffers need **3.3 V on VCC** (never 5 V).
  The J10 jumper route (or a DE-15 breakout + 9 resistors) avoids the
  ambiguity entirely.
- ~~Green channel lost at 15 kHz on a 15 kHz-capable LCD~~ **RESOLVED
  2026-07**: the display had mis-detected the sync format. 15 kHz now
  defaults to **separate H and V sync** (also what a real MCR cabinet wants,
  Video pins 8/9); composite sync remains available on the J10-39 strap.
  Two lessons worth keeping: a mis-detected sync format can look exactly
  like a dead colour channel, and **displays latch their format detection**
  — switching format on a live signal may not re-trigger it, which made an
  earlier four-way test look like a total failure when one combination
  actually worked.
- **New games' controls are derived, not played.** Trackball/analogue-stick
  sensitivity on a d-pad is guesswork — Kroozr's stick ramp rate especially.
  Tron's aim direction may need reversing (MAME marks the dial PORT_REVERSE).
- **Two Tigers has +0.08 ns setup slack** — met, but the tightest of the six.
  Suspect timing first if that game alone misbehaves.

---

## Multi-game / product

- **OSD game-select menu is IMPLEMENTED (60K)** — `src/rtl/osd.sv`, drawn in
  the core raster domain so it shows on HDMI + VGA 31 kHz + 15 kHz alike.
  Select+Start opens; Up/Down, A = load slot from SD pack, B = exit. All six
  input maps are now compiled in and muxed at runtime by `game_id`;
  `game_config.vh` only picks the baked-in boot game. **Working on
  hardware 2026-07-21** (menu, SD reload, game switching; navigation
  debounce fixed by frame-rate button sampling). Remaining OSD work:
  - **ROT90 direction unverified**: menu on Tron/Shollow is drawn rotated
    for a cabinet monitor; if it reads mirrored/upside-down, swap the
    mapping noted in `osd.sv` (u/v remap line).
  - **"LOADING..." is never visible**: the core raster stops while the core
    is reset during a reload, so the screen freezes (HDMI) / drops sync
    (VGA) for ~1 s instead. Fix would be keeping the video counters running
    through reset in `mcr2.vhd` (touchy — it's shared with the 25K).
  - **Opening the menu inserts a coin** (Select doubles as Coin1 before the
    Start half of the combo lands). Harmless; goes away when the shield's
    dedicated service button opens the menu instead.
  - **Stale CMOS RAM across switches**: each game boots on the previous
    game's CMOS contents; MCR games checksum it and factory-reset, so this
    should self-heal — verify per game, else clear cmos_ram on reload.
  - ~~No prefs persistence~~ **DONE 2026-07-21**: selections are written
    to SD sector 2047 (CMD24) and win over the baked default at power-on;
    sim-verified round trip (`make -C sim`). Untested on hardware.
  - **Two Tigers' Dogfight Start moved to D-pad Up** (was Select+Start,
    which is now the menu combo).
- **No multiboot selector** for switching MCR family cores (2.5 MB per core,
  so all three fit well under 8 MB of flash).
- **Fallback behaviour is minimal.** Loader failure falls back to the baked
  ROMs and the OSD shows "LOAD FAILED"; the shield spec still wants a status
  LED so a field failure is diagnosable without a display.

## Shield PCB

- **5 V delivery route unverified** — J10 pin 11 exposes +5 V but sits behind
  the dock's OR-ing/OVP chain; do not back-feed it until traced. USB-C is the
  known-good path.
- **Header pinout is FROZEN (2026-07-21): `docs/shield_j10_pinout.md`.**
  Everything on J10 only — video/audio/straps/LEDs on the pins today's
  bitstreams already drive, ALL cabinet inputs + both DIP banks on a
  7×74AHC165 chain (3 pins; 3.3 V parts, 5 V-tolerant inputs), outputs on a 74HC595+ULN2803 chain (4 pins),
  service button direct. This resolved the old J6/IP4 gap (chain device
  U5) and the lamp/coin-meter question ('595 chain, extensible free).
  Remaining on it:
  - **Expander-chain RTL does not exist yet** — a small module scanning
    the '165s into the input mux (ORed with the USB pad), driving the
    '595s, and a SERVICE_N → OSD-open hook. J10 pins 25-34 are reserved
    and high-Z until then; the shield works for video/audio/straps/LEDs
    with current bitstreams on day one.
  - J6's *cabinet-side* connector wiring wants a manual cross-check
    before crimping harnesses (the matrix PDF has no J6 sheet).
- **`tools/generate_pcb.py` is not synced** to `shield_j10_pinout.md`, and
  still assumes generic 2×20 headers; J9 must stay clear for the SDRAM
  module.
- **138K variant**: header nets are dock-level but the net→ball map is
  SOM-specific; re-extract before targeting it.

## Cores / ports

- **See `docs/mcr_core_roadmap.md`** for the phased plan. All ROMs in `roms/`.
- **SDRAM memtest — Phase B started, not yet on hardware.** Standalone
  test of the Tang SDRAM module (J9) using the exact controller MCR-3 will
  use (`src/rtl/sdram_gw.sv`, Gowin-adapted from MiSTer MCR-3). Flash
  `bitstreams/console60k_sdram_memtest.fs` with the module plugged in:
  J10 LED debug_o[0]=PASS, [1]=DONE, [2]=FAIL, [3]=heartbeat; UART beacon
  shows progress then c1/c0. FSM Verilator-validated. If reads fail, first
  suspect the SDRAM_CLK phase (swap D0/D1 on the ODDR in sdram_gw.sv).
  This gates all MCR-3/Scroll/Mono cores.
- **MCR-1 (Kick/Kickman/Solar Fox) — Phase A builds, not yet on hardware.**
  `src/rtl/mcr1.vhd` + `mcr1_console60k/`; bitstreams
  `bitstreams/console60k_mcr1_{kick,solarfox}.fs` (BSRAM 77/118, setup
  +0.585 ns, checks clean). To verify on hardware:
  `openFPGALoader -b tangconsole -f bitstreams/console60k_mcr1_kick.fs`.
  Open items: hardware bring-up (video/sound/controls); Kick spinner
  sensitivity + DIP defaults (input_3 = 0xFF placeholder) need tuning; OSD
  text rotation direction on the rotated MCR-1 monitors is a guess; SD pack
  switching for MCR-1 needs pack-format-v2 (make_rompack currently MCR-2
  only). One maintenance debt: the MCR-1 top is a copy of the MCR-2 top -
  a future refactor to a unified family-ifdef top would remove the
  duplicated video/USB/SD/OSD infrastructure (deferred to protect the
  working MCR-2 build during its own hardware validation).
- **Tang Primer 25K project is stale**: still the line-buffer video path and
  a Satan's Hollow input map. Fine as-is, but it no longer matches the 60K.
- **Tang Console 138K project is stale**: pre-framebuffer architecture.

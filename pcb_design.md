# Universal MCR Daughterboard PCB Design Specification

This document details the physical layout, component placement, and schematic netlist for the **Universal Bally Midway MCR Cabinet Interface Shield** designed to host the **Tang Console 60K/138K**. It includes an ASCII floorplan and a **KiCad Python Script** to programmatically generate the board layout.

---

## 1. PCB Floorplan (ASCII Layout Sketch)

The PCB is designed as a roomy carrier shield (approx. **135mm x 95mm**) that sits directly underneath the Tang Console board, exposing the original cabinet connectors along the top and bottom edges.

![KiCad Layout Render](/Users/alans/.gemini/antigravity/brain/20b49b60-7808-4192-a474-5a5b1ce4d262/mcr_shield_v7.png)

```text
+-----------------------------------------------------------------------------------+
|  [J2: P1 Ctrl]     [J3: Coin/Start]      [Video Output]       [Power Input +12V]  |
|  (Molex 15-pin)      (Molex 5-pin)        (Molex 9-pin)         (Screw Terminal)  |
|                                                                                   |
|    +---------------------------------------------------------+   +------------+   |
|    |               Tang Console 60K/138K Socket              |   | 5V Buck    |   |
|    |               (Exposes 2x20 Pin Header 1)               |   | Regulator  |   |
|    +---------------------------------------------------------+   +------------+   |
|                                                                                   |
|  [Optocouplers]                                                  [Audio Amp]      |
|  (TLP281-4)                                                      (LM386 + Caps)   |
|                                                                                   |
|    +---------------------------------------------------------+   [Audio Out]      |
|    |               Tang Console 60K/138K Socket              |   (Screw Term)     |
|    |               (Exposes 2x20 Pin Header 2)               |                    |
|    +---------------------------------------------------------+                    |
|                                                                  [DAC Resistors]  |
|                                                                  (R2R Networks)   |
|  [J5: P2 / Trackball]                 [J4: Opt X / Spinner]                       |
|  (Molex 19-pin)                         (Molex 10-pin)                            |
|                                                                                   |
|                     [SW1: Game Sel]      [SW2: Options]                           |
|                     (8-Position DIP)     (8-Position DIP)                         |
+-----------------------------------------------------------------------------------+
```

---

## 2. Schematic Netlist Configuration

The daughterboard connects the Tang Console 2x20 headers directly to the cabinet connectors and onboard modules:

### Power Distribution Nets
*   `+12V_CAB` $\rightarrow$ Screw Terminal Pin 1 $\rightarrow$ Audio Amp VCC, Buck Regulator Input.
*   `GND` $\rightarrow$ Common ground across all connectors, switches, and regulators.
*   `+5V_REG` $\rightarrow$ Buck Regulator Output $\rightarrow$ Tang Console 5V input pins (Header 1).
*   `+3.3V_FPGA` $\rightarrow$ Tang Console 3.3V output pins (Header 2) $\rightarrow$ DIP Switch pull-ups, optocoupler output pull-ups.

### Video DAC Nets
*   `cab_r[2:0]` $\rightarrow$ R2R Resistor Network $\rightarrow$ `MCR_RED` $\rightarrow$ `Video-1`
*   `cab_g[2:0]` $\rightarrow$ R2R Resistor Network $\rightarrow$ `MCR_GREEN` $\rightarrow$ `Video-3`
*   `cab_b[2:0]` $\rightarrow$ R2R Resistor Network $\rightarrow$ `MCR_BLUE` $\rightarrow$ `Video-5`
*   `cab_hs` $\rightarrow$ NPN Transistor Buffer $\rightarrow$ `MCR_HSYNC` $\rightarrow$ `Video-8`
*   `cab_vs` $\rightarrow$ NPN Transistor Buffer $\rightarrow$ `MCR_VSYNC` $\rightarrow$ `Video-9`
*   `Video GND` $\rightarrow$ Connected directly to `GND` $\rightarrow$ `Video-2, Video-4, Video-6`

---

## 3. KiCad PCB Python Generation Script

To prevent code desynchronization, the Python generator script is maintained separately at [`tools/generate_pcb.py`](file:///Users/alans/Documents/development/Arcade-MCR2-TangFPGA/tools/generate_pcb.py).

### How to Run the Generator:
To programmatically generate the layout or apply changes to coordinates, execute the script from your terminal using KiCad's bundled Python interpreter:

```bash
# Run the script to generate or update 'mcr_shield.kicad_pcb'
/Applications/KiCad/KiCad.app/Contents/Frameworks/Python.framework/Versions/3.9/bin/python3 tools/generate_pcb.py
```

After running the script, the updated board database is saved directly to [`mcr_shield.kicad_pcb`](file:///Users/alans/Documents/development/Arcade-MCR2-TangFPGA/mcr_shield.kicad_pcb). You can open this file in KiCad PCB Editor to view and route the traces.

---

## 4. Power Supply & Level-Shifting Specification

Arcade cabinets are electrically noisy environments. Proper power isolation and input level-shifting are critical to ensure that the delicate FPGA logic is not damaged and does not suffer from glitches.

### A. Power Supplies Required
Original MCR cabinets deliver:
1.  **+5V DC (Logic):** Used to power TTL ICs on the original boards.
2.  **+12V DC (Audio):** Used to run the audio power amplifiers.
3.  **-5V DC (Bias):** Used only by legacy dynamic RAMs (4116 DRAM). 
    *   *Our core runs 100% on-chip static BRAM, so **we do not need the -5V rail at all**.*

**How we power the FPGA:**
*   We route the cabinet's **+12V DC rail** to an onboard **step-down Buck Regulator module** (e.g. LM2596 or similar buck converter) on our shield. The regulator outputs a rock-solid, filtered **+5.0V DC** (1.5A rating) which is routed directly to the Tang Console's 5V input pin.
*   This isolates the FPGA from noise on the cabinet's main +5V logic lines and prevents brownouts when solenoids or coin door lights trigger.

### B. Input Level-Shifting (Cabinet Controls)
*   **The Hazard:** Standard arcade cabinet switches can pick up high-voltage static shocks (ESD) or line noise from the CRT monitor. Since the Gowin FPGA GPIOs are **strictly 3.3V tolerant**, connecting long wire loops directly to the pins will eventually destroy the FPGA.
*   **The Solution (Optocouplers):** We place **TLP281-4 (or EL817-4) quad optocouplers** on all cabinet input lines (joysticks, buttons, coins).
    *   The cabinet loop runs at +5V/12V through the optocoupler's input LED.
    *   When a switch is closed, it triggers the internal LED.
    *   The output photo-transistor bridges the FPGA GPIO directly to `GND` (pulled up to `+3.3V` internally).
    *   This provides **100% electrical isolation** between the cabinet and the FPGA.

### C. Output Level-Shifting (Video Sync)
*   **Sync Signals:** Arcade CRT monitors expect **5V TTL composite sync** signals. The FPGA outputs 3.3V. While some monitors may work, it is best practice to place a buffer IC (like a **74LVC244** or **74HCT244**) powered by +5V to step up the 3.3V HSync, VSync, and CSync signals to solid 5V TTL levels before routing them to the video connector.
*   **RGB Colors:** The R2R resistor network naturally performs the level-shifting from 3.3V digital logic to the analog 0.7V peak-to-peak expected by the CRT monitor. **No active buffer or level shifter is needed for RGB signals.**


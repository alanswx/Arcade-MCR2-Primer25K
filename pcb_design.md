# Universal MCR Daughterboard PCB Design Specification

This document details the physical layout, component placement, and schematic netlist for the **Universal Bally Midway MCR Cabinet Interface Shield** designed to host the **Tang Console 60K/138K**. It includes an ASCII floorplan and a **KiCad Python Script** to programmatically generate the board layout.

---

## 1. PCB Floorplan (ASCII Layout Sketch)

The PCB is designed as a roomy carrier shield (approx. **135mm x 95mm**) that sits directly underneath the Tang Console board, exposing the original cabinet connectors along the top and bottom edges.

![KiCad Layout Render](/Users/alans/.gemini/antigravity/brain/20b49b60-7808-4192-a474-5a5b1ce4d262/mcr_shield_v6.png)

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

To programmatically build this board, open KiCad's **PCB Editor**, open the **Scripting Console** (`Tools -> Scripting Console`), copy the Python script below, and run it. It will automatically initialize the board, draw the edge cuts, and place the critical connector headers at their exact coordinates.

```python
import pcbnew
from pcbnew import wxPoint, wxSize, EDA_IU_TO_MM

def generate_mcr_shield():
    # Initialize a new board project
    board = pcbnew.GetBoard()
    if not board:
        board = pcbnew.BOARD()
        pcbnew.SetActiveBoard(board)

    # Clean existing items
    board.DeleteAll()

    # Define board dimensions: 120mm x 100mm (values in micrometers)
    width = 120.0
    height = 100.0
    margin = 5.0

    # Draw PCB Edge Outline on the Edge.Cuts layer
    edge_layer = board.GetLayerID("Edge.Cuts")
    
    # Coordinates in nanometers (1mm = 1,000,000 nm)
    x_min, y_min = int(margin * 1000000), int(margin * 1000000)
    x_max, y_max = int((width + margin) * 1000000), int((height + margin) * 1000000)

    corners = [
        wxPoint(x_min, y_min),
        wxPoint(x_max, y_min),
        wxPoint(x_max, y_max),
        wxPoint(x_min, y_max)
    ]

    for i in range(4):
        p1 = corners[i]
        p2 = corners[(i + 1) % 4]
        seg = pcbnew.PCB_SHAPE(board)
        seg.SetShape(pcbnew.SHAPE_T_SEGMENT)
        seg.SetStart(p1)
        seg.SetEnd(p2)
        seg.SetLayer(edge_layer)
        board.Add(seg)

    print("PCB Edge Outline drawn successfully!")

    # Helper function to place standard connectors/pin headers
    def place_connector(reference, value, footprint_name, x_mm, y_mm, rotation_deg=0):
        # Load standard KiCad connector footprints
        footprint = pcbnew.FootprintLoad(board.GetProject(), footprint_name)
        if not footprint:
            # Fallback to standard library connector if custom not loaded
            footprint = pcbnew.FootprintLoad("", "Connector_PinHeader_2.54mm:PinHeader_1x02_P2.54mm_Vertical")
        
        if footprint:
            footprint.SetReference(reference)
            footprint.SetValue(value)
            
            # Position (convert mm to nanometers)
            pos = wxPoint(int(x_mm * 1000000), int(y_mm * 1000000))
            footprint.SetPosition(pos)
            footprint.SetOrientation(rotation_deg * 10) # KiCad expects 10th of a degree
            
            board.Add(footprint)
            print(f"Placed {reference} ({value}) at X={x_mm}mm, Y={y_mm}mm")

    # --- Place Connectors and Headers ---
    # 1. Tang Console Host Sockets (2x20 Pin Headers spaced 50mm apart)
    place_connector("JP1", "Tang_2x20_H1", "Connector_PinHeader_2.54mm:PinHeader_2x20_P2.54mm_Vertical", 65.0, 45.0)
    place_connector("JP2", "Tang_2x20_H2", "Connector_PinHeader_2.54mm:PinHeader_2x20_P2.54mm_Vertical", 65.0, 65.0)

    # 2. MCR Top Connectors (Controls, Coin, Video, Power)
    place_connector("J2", "MCR_P1_Controls", "Connector_PinHeader_2.54mm:PinHeader_1x15_P2.54mm_Vertical", 20.0, 12.0)
    place_connector("J3", "MCR_System_Coin", "Connector_PinHeader_2.54mm:PinHeader_1x05_P2.54mm_Vertical", 55.0, 12.0)
    place_connector("J_VID", "MCR_Video_Out", "Connector_PinHeader_2.54mm:PinHeader_1x09_P2.54mm_Vertical", 85.0, 12.0)
    place_connector("P_IN", "Power_+12V_GND", "Connector_PinHeader_2.54mm:PinHeader_1x02_P2.54mm_Vertical", 115.0, 12.0)

    # 3. MCR Bottom Connectors (P2 Controls, Spinners, DIP Switches)
    place_connector("J5", "MCR_P2_Controls", "Connector_PinHeader_2.54mm:PinHeader_1x19_P2.54mm_Vertical", 25.0, 93.0)
    place_connector("J4", "MCR_Opt_X_Dial", "Connector_PinHeader_2.54mm:PinHeader_1x10_P2.54mm_Vertical", 75.0, 93.0)
    
    # 4. DIP Switch Blocks
    place_connector("SW1", "Game_Selector", "Button_Switch_THT:SW_DIP_SPSTx08_Slide_9.78x22.5mm_W7.62mm_P2.54mm", 100.0, 93.0)
    place_connector("SW2", "Cabinet_Options", "Button_Switch_THT:SW_DIP_SPSTx08_Slide_9.78x22.5mm_W7.62mm_P2.54mm", 115.0, 93.0)

    # Refresh KiCad canvas view
    pcbnew.Refresh()

# Execute script
generate_mcr_shield()
```

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


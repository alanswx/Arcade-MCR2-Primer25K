# Bally Midway MCR2 Arcade Core for Gowin Tang FPGAs

This repository contains the standalone, hardcoded ports of Bally Midway's MCR2 arcade core (supporting games like *Satan's Hollow*, *Tron*, etc.) for the **Sipeed Tang** series of Gowin FPGA development boards.

We support three physical configurations concurrently:
1.  **Sipeed Tang Primer 25K (GW5A-LV25)**
2.  **Sipeed Tang Console 60K (GW5A-LV60)**
3.  **Sipeed Tang Console 138K (GW5AST-LV138)**

Both the 60K and 138K ports run **100% on-chip in full Block RAM (BRAM) mode** (119.5 KB of CPU/sound/graphics ROMs + working memory), completely bypassing the need for external DDR3/SDRAM controllers. This results in zero latency, zero wait states, and no memory bus contention.

---

## 1. Project Directory Structure

To maximize code reuse, the repository is organized with a shared source directory and independent board-level project folders:

*   **[`src/`](file:///Users/alans/Documents/development/Arcade-MCR2-TangFPGA/src/) (Platform-Independent Shared Source Code):**
    *   `src/rtl/`: Core VHDL/SystemVerilog files (`mcr2.vhd`, Z80 CPUs, Z80CTC, RAM wrappers).
    *   `src/audio/`: Shared Delta-Sigma audio DAC.
    *   `src/dvi_tx/`: Shared HDMI serialization logic.
    *   `src/roms/`: Initialized Satan's Hollow ROM hex tables.
*   **[`mcr2_primer25k/`](file:///Users/alans/Documents/development/Arcade-MCR2-TangFPGA/mcr2_primer25k/):** Gowin project, top-level wrapper, and constraints for the Tang Primer 25K.
*   **[`mcr2_console60k/`](file:///Users/alans/Documents/development/Arcade-MCR2-TangFPGA/mcr2_console60k/):** Gowin project, top-level wrapper, and constraints for the Tang Console 60K.
*   **[`mcr2_console138k/`](file:///Users/alans/Documents/development/Arcade-MCR2-TangFPGA/mcr2_console138k/):** Gowin project, top-level wrapper, and constraints for the Tang Console 138K.

---

## 2. Compilation Instructions

1.  Launch the **Gowin IDE** (Yunyuan) on your PC.
2.  Select **Open Project** and open the project file for your specific target board:
    *   For Tang Primer 25K: [`mcr2_primer25k/mcr2_primer25k.gprj`](file:///Users/alans/Documents/development/Arcade-MCR2-TangFPGA/mcr2_primer25k/mcr2_primer25k.gprj)
    *   For Tang Console 60K: [`mcr2_console60k/mcr2_console60k.gprj`](file:///Users/alans/Documents/development/Arcade-MCR2-TangFPGA/mcr2_console60k/mcr2_console60k.gprj)
    *   For Tang Console 138K: [`mcr2_console138k/mcr2_console138k.gprj`](file:///Users/alans/Documents/development/Arcade-MCR2-TangFPGA/mcr2_console138k/mcr2_console138k.gprj)
3.  Click **Process** $\rightarrow$ **Run All** in the IDE. This will run synthesis, mapping, and place-and-route to generate the binary bitstream file (`.fs`) under the selected project's `impl/` directory.
4.  Open the **Gowin Programmer**, connect the board's JTAG, and program the `.fs` bitstream file to the FPGA SRAM or Flash memory.

---

## 3. Hardware Integration & Custom Shield Design

To mount these boards inside an original Bally Midway MCR cabinet, we design custom daughterboard shields (Option A) to interface with the cabinet's original wire harness.

*   For a comparative analysis of the boards and custom shield manufacturing cost estimates, see the **[FPGA Board Comparison & Custom Shield BOM](file:///Users/alans/Documents/development/Arcade-MCR2-TangFPGA/board_comparison_and_bom.md)**.
*   For the complete electrical specifications, level-shifting, DAC schematics, and pinout routing tables for each board, see the **[MCR2 V2 Handoff & PCB Design Specification](file:///Users/alans/Documents/development/Arcade-MCR2-TangFPGA/handoff_v2_design.md)**.

# Walkthrough of Bally Midway MCR2 Multi-Board FPGA Port

This port converts the Cyclone V (MiSTer) Bally Midway MCR2 arcade core into a standalone, hardcoded core running on Gowin Aurora GW5A FPGAs. We support the **Tang Primer 25K**, **Tang Console 60K**, and **Tang Console 138K** boards concurrently.

---

## 1. Accomplished Work

*   **Repository Reorganization:** Restructured the repository by extracting all platform-independent assets to a global `src/` directory. All boards now share the exact same VHDL/SystemVerilog core files, audio generators, HDMI serializers, and ROM hex tables, preventing any code duplication.
*   **Tang Console 60K & 138K Ports:** Created dedicated board directories (`mcr2_console60k/` and `mcr2_console138k/`) with compile-ready project configurations, pin constraint files, timing constraint files, and top-level SV wrappers.
*   **On-Chip BRAM Optimization (60K/138K):** Configured both the 60K and 138K cores to run in **100% On-Chip BRAM mode**. Since the 60K chip has 320KB of internal block RAM and the 138K has 765KB, the entire core (119.5KB of CPU/sound/graphics ROMs + working memory) fits completely on-chip with zero latency, zero wait states, and no external memory controllers needed.

---

## 2. Directory Structure

The repository is structured as a shared codebase with independent board projects:

*   **`src/` (Shared platform-independent code):**
    *   `src/rtl/`: Core VHDL/SystemVerilog files (`mcr2.vhd`, Z80 CPUs, timers, RAM wrappers).
    *   `src/audio/`: Shared Delta-Sigma audio DAC.
    *   `src/dvi_tx/`: Shared HDMI serialization logic.
    *   `src/roms/`: Initialized Satan's Hollow ROM hex tables.
*   **`mcr2_primer25k/`:** Gowin project and constraints for the Tang Primer 25K.
*   **`mcr2_console60k/`:** Gowin project and constraints for the Tang Console 60K.
*   **`mcr2_console138k/`:** Gowin project and constraints for the Tang Console 138K.

---

## 3. How to Compile the Ports

1.  Open the **Gowin IDE** (Yunyuan) on your PC.
2.  Choose **Open Project** and navigate to your target board's project file:
    *   For Tang Primer 25K: [mcr2_primer25k.gprj](file:///Users/alans/Documents/development/Arcade-MCR2-Primer25K/mcr2_primer25k/mcr2_primer25k.gprj)
    *   For Tang Console 60K: [mcr2_console60k.gprj](file:///Users/alans/Documents/development/Arcade-MCR2-Primer25K/mcr2_console60k/mcr2_console60k.gprj)
    *   For Tang Console 138K: [mcr2_console138k.gprj](file:///Users/alans/Documents/development/Arcade-MCR2-Primer25K/mcr2_console138k/mcr2_console138k.gprj)
3.  Click **Process** $\rightarrow$ **Run All** in the IDE to run synthesis, placement, and routing.
4.  The generated `.fs` bitstream file will be created in the `impl/` directory of the selected project folder. Write this to your FPGA using the **Gowin Programmer**.

*Note: The constraint files (`.cst`) for the Console 60K/138K ports map clocks and HDMI signals to standard pins, and leave cabinet controls/video signals as placeholder headers. Edit the `.cst` files to match your custom Shield PCB layout when finalized.*

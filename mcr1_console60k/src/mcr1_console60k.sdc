// Timing constraints for MCR2 on Tang Console 60K
// Primary 50MHz input clock on pin sys_clk (period = 20ns).
create_clock -name sys_clk -period 20 -waveform {0 10} [get_ports {sys_clk}]

// Explicitly declare the PLL generated core clock. Naming it here (rather
// than relying on the tool's auto-derived "default_gen_clk" names, which are
// not queryable at SDC-parse time) lets us reference it in set_clock_groups.
//   clk_sys = 40MHz = sys_clk * 4/5   (PLLA CLKOUT1, core clock)
create_generated_clock -name clk_sys -source [get_ports {sys_clk}] -multiply_by 4 -divide_by 5 [get_pins {pll_inst/PLLA_inst/CLKOUT1}]

// DDR3 framebuffer clocks (per nand2mario gbatang_ddr.sdc): the DDR3 PLL is
// mDRP-reconfigured at runtime, so its outputs are declared explicitly.
//   clk4x = 297MHz DDR3 memory clock, clk1x = 74.25MHz pixel/user clock.
// The framebuffer crosses clk_sys -> clk1x through its internal async FIFO,
// so these domains are asynchronous to the core clock.
create_clock -name clk4x -period 3.367 -waveform {0 1.684} [get_nets {fb_inst/memory_clk}]
create_clock -name clk1x -period 13.47 -waveform {0 6.734} [get_nets {fb_inst/clk_x1}]
set_clock_groups -asynchronous -group [get_clocks {clk_sys}] -group [get_clocks {clk4x}]
set_clock_groups -asynchronous -group [get_clocks {clk4x}] -group [get_clocks {clk1x}]
set_clock_groups -asynchronous -group [get_clocks {clk_sys}] -group [get_clocks {clk1x}]

// USB HID host clock: 12MHz from the second PLLA (50 * 6/25). The pad outputs
// are 2FF-synchronized into clk_sys, so the domains are asynchronous.
create_generated_clock -name clk_usb -source [get_ports {sys_clk}] -multiply_by 6 -divide_by 25 [get_pins {pll_usb_inst/PLLA_inst/CLKOUT0}]
set_clock_groups -asynchronous -group [get_clocks {clk_usb}] -group [get_clocks {clk_sys}]

// --- HDMI clocks from the framebuffer's internal PLL -----------------------
// gbatang ships these commented out and we inherited that. It cost a long
// debug session: with hclk5 unconstrained the tool never knew the OSER10
// TMDS serializers run at 371.25 MHz, so it placed and routed those paths
// with no timing requirement at all. HDMI produced nothing, while a simple
// 25 MHz encoder driving the same pins worked perfectly - and every clock
// measured correct, because the clocks were never the problem.
//
// gbatang gets away with it because their design is nearly empty; ours adds
// the MCR core, USB host, SD loader, analog video and the beacon on top of
// the same framebuffer, so unconstrained paths end up wherever there is room.
create_clock -name hclk5 -period 2.694  -waveform {0 1.347} [get_nets {fb_inst/hclk5}]
// (hclk is visible at the top level as fb_hclk - the hclk_dbg output - since
// synthesis merges the internal net with it.)
create_clock -name hclk  -period 13.468 -waveform {0 6.734} [get_nets {fb_hclk}]

// The HDMI domain only meets the rest of the design inside the framebuffer's
// own synchronisers, so cut it from the core and DDR3 clocks (hclk/hclk5 are
// left related to each other - they come from one PLL).
set_clock_groups -asynchronous -group [get_clocks {hclk5 hclk}] -group [get_clocks {clk_sys}]
set_clock_groups -asynchronous -group [get_clocks {hclk5 hclk}] -group [get_clocks {clk4x}]
set_clock_groups -asynchronous -group [get_clocks {hclk5 hclk}] -group [get_clocks {clk1x}]

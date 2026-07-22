// SDRAM memtest timing - Tang Console 60K
create_clock -name sys_clk -period 20 -waveform {0 10} [get_ports {sys_clk}]
// clk100 = 100 MHz = sys_clk * 2 (PLLA CLKOUT0)
create_generated_clock -name clk100 -source [get_ports {sys_clk}] -multiply_by 2 [get_pins {pll_inst/PLLA_inst/CLKOUT0}]

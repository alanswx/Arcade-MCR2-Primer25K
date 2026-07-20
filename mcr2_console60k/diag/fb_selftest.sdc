create_clock -name sys_clk -period 20 -waveform {0 10} [get_ports {sys_clk}]
create_clock -name clk4x -period 3.367 -waveform {0 1.684} [get_nets {fb/memory_clk}]
create_clock -name clk1x -period 13.47 -waveform {0 6.734} [get_nets {fb/clk_x1}]
create_clock -name hclk5 -period 2.694 -waveform {0 1.347} [get_nets {fb/hclk5}]

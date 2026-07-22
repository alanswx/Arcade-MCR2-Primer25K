# SDRAM module self-test for Tang Console 60K (roadmap Phase B).
# Run headless from mcr2_console60k/ : gw_sh diag/build_sdram.tcl
set_device GW5AT-LV60PG484AC1/I0 -device_version B
set_option -synthesis_tool gowinsynthesis
set_option -output_base_name sdram_memtest
set_option -top_module sdram_memtest_top
set_option -verilog_std sysv2017
set_option -place_option 2
set_option -ireg_in_iob 1
set_option -oreg_in_iob 1
set_option -ioreg_in_iob 1
# free dual-purpose config pins (some SDRAM/J-header balls overlap them)
set_option -use_cpu_as_gpio 1
set_option -use_mspi_as_gpio 1
set_option -use_sspi_as_gpio 1
set_option -use_ready_as_gpio 1
set_option -use_done_as_gpio 1
set_option -use_i2c_as_gpio 1

add_file diag/sdram_memtest_top.sv
add_file ../src/rtl/gowin_pll_sdram.v
add_file ../src/rtl/sdram_gw.sv
add_file ../src/rtl/sdram_memtest.sv
add_file ../src/rtl/uart_beacon.sv
add_file -type cst diag/sdram_memtest.cst
add_file -type sdc diag/sdram_memtest.sdc
run all

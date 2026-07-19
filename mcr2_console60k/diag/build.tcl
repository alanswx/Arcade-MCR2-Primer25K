set_device GW5AT-LV60PG484AC1/I0 -device_version B
set_option -synthesis_tool gowinsynthesis
set_option -output_base_name hdmi_selftest
set_option -top_module hdmi_selftest_top
set_option -verilog_std sysv2017
set_option -place_option 2
add_file diag/hdmi_selftest_top.sv
add_file ../src/rtl/gowin_pll_mcr2.v
add_file ../src/dvi_tx/tmds_encoder.sv
add_file ../src/dvi_tx/hdmi_tx.sv
add_file ../src/rtl/uart_beacon.sv
add_file -type cst diag/hdmi_selftest.cst
add_file -type sdc diag/hdmi_selftest.sdc
run all

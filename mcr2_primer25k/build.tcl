# Gowin TCL Build Script for MCR2 Arcade Core on Tang Primer 25K

# Set device details
set_device GW5A-LV25MG121NC1/I0 -device_version A

# Set synthesis options
set_option -synthesis_tool gowinsynthesis
set_option -output_base_name mcr2_primer25k
set_option -top_module mcr2_primer25k_top
set_option -verilog_std sysv2017
set_option -rw_check_on_ram 1
set_option -use_mspi_as_gpio 1
set_option -use_ready_as_gpio 1
set_option -use_done_as_gpio 1
set_option -use_i2c_as_gpio 1
set_option -use_cpu_as_gpio 1
set_option -multi_boot 1

# Add source files
add_file src/mcr2_primer25k_top.sv
add_file ../src/rtl/dpram.sv
add_file ../src/rtl/gen_ram.sv
add_file ../src/rtl/gowin_pll_mcr2.v
add_file ../src/dvi_tx/tmds_encoder.sv
add_file ../src/dvi_tx/hdmi_tx.sv
add_file ../src/audio/ds_dac.sv

# Add core files (VHDL/SystemVerilog)
add_file ../src/rtl/mcr2.vhd
add_file ../src/rtl/mcr_sound_board.vhd
add_file ../src/rtl/YM2149_linmix_sep.vhd
add_file ../src/rtl/midssio_82s123.vhd
add_file ../src/rtl/cmos_ram.vhd
add_file ../src/rtl/spinner.sv

# Add CPU/CTC VHDL files
add_file ../src/rtl/T80/t80_1_alu.vhd
add_file ../src/rtl/T80/t80_2_mcode.vhd
add_file ../src/rtl/T80/t80_3_reg.vhd
add_file ../src/rtl/T80/t80_4_core.vhd
add_file ../src/rtl/T80/t80_5_pa.vhd
add_file ../src/rtl/T80/t80_6_s.vhd
add_file ../src/rtl/Z80CTC/ctc_controler.vhd
add_file ../src/rtl/Z80CTC/ctc_counter.vhd
add_file ../src/rtl/Z80CTC/z80ctc_top.vhd

# Add constraints files
add_file -type cst src/mcr2_primer25k.cst
add_file -type sdc src/mcr2_primer25k.sdc

# Run synthesis, map, and place-and-route
run all

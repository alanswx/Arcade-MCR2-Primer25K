# Gowin TCL Build Script for MCR2 Arcade Core on Tang Console 60K
# Run headless from mcr2_console60k/ (see CLAUDE.md for the gw_sh invocation).

# Set device details
set_device GW5AT-LV60PG484AC1/I0 -device_version B

# Set synthesis options
set_option -synthesis_tool gowinsynthesis
set_option -output_base_name mcr2_console60k
set_option -top_module mcr2_console60k_top
set_option -verilog_std sysv2017
set_option -rw_check_on_ram 1
set_option -multi_boot 1

# Match nand2mario/gbatang's build settings (DDR3 IP donor design):
# IOB register packing + placer algorithm 2.
set_option -ireg_in_iob 1
set_option -oreg_in_iob 1
set_option -ioreg_in_iob 1
set_option -place_option 2

# Free the dual-purpose config pins as regular GPIO. The J10 header
# (SDRAM1 bus) overlaps the CPU-mode config DBUS (R19/P19/U21/T21 = D0-D3)
# and the SSPI/MSPI pins (V17/AB20/AA19); without these options PnR fails
# with PR2017 "dedicated pin (CPU)".
set_option -use_cpu_as_gpio 1
set_option -use_mspi_as_gpio 1
set_option -use_sspi_as_gpio 1
set_option -use_ready_as_gpio 1
set_option -use_done_as_gpio 1
set_option -use_i2c_as_gpio 1

# Add source files
add_file src/mcr2_console60k_top.sv
add_file ../src/rtl/dpram.sv
add_file ../src/rtl/gen_ram.sv
add_file ../src/rtl/gowin_pll_mcr2.v
add_file ../src/usb/gowin_pll_usb.v
add_file ../src/usb/usb_hid_host.v
add_file ../src/usb/usb_hid_host_rom.v
add_file ../src/audio/ds_dac.sv
add_file ../src/rtl/uart_beacon.sv
add_file ../src/rtl/sd_spi_phy.sv
add_file ../src/rtl/sd_reader.sv
add_file ../src/rtl/rom_loader.sv
add_file ../src/rtl/osd.sv

# DDR3 framebuffer + 720p HDMI w/ audio (vendored from nand2mario/gbatang)
add_file ../src/ddr3fb/ddr3_framebuffer.v
add_file ../src/ddr3fb/ddr3_memory_interface.v
add_file ../src/ddr3fb/pll_27.v
add_file ../src/ddr3fb/pll_ddr3.v
add_file ../src/ddr3fb/gowin_pll_hdmi27.v
add_file ../src/ddr3fb/pll_mDRP_intf.v
add_file ../src/ddr3fb/hdmi/audio_clock_regeneration_packet.sv
add_file ../src/ddr3fb/hdmi/audio_info_frame.sv
add_file ../src/ddr3fb/hdmi/audio_sample_packet.sv
add_file ../src/ddr3fb/hdmi/auxiliary_video_information_info_frame.sv
add_file ../src/ddr3fb/hdmi/hdmi.sv
add_file ../src/ddr3fb/hdmi/packet_assembler.sv
add_file ../src/ddr3fb/hdmi/packet_picker.sv
add_file ../src/ddr3fb/hdmi/serializer.sv
add_file ../src/ddr3fb/hdmi/source_product_description_info_frame.sv
add_file ../src/ddr3fb/hdmi/tmds_channel.sv

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
add_file -type cst src/mcr2_console60k.cst
add_file -type sdc src/mcr2_console60k.sdc

# Run synthesis, map, and place-and-route
run all

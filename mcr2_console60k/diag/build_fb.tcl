set_device GW5AT-LV60PG484AC1/I0 -device_version B
set_option -synthesis_tool gowinsynthesis
set_option -output_base_name fb_selftest
set_option -top_module fb_selftest_top
set_option -verilog_std sysv2017
set_option -place_option 2
set_option -use_sspi_as_gpio 1
set_option -use_mspi_as_gpio 1
set_option -use_cpu_as_gpio 1
add_file diag/fb_selftest_top.sv
add_file ../src/rtl/gowin_pll_mcr2.v
add_file ../src/ddr3fb/ddr3_framebuffer.v
add_file ../src/ddr3fb/ddr3_memory_interface.v
add_file ../src/ddr3fb/pll_27.v
add_file ../src/ddr3fb/pll_ddr3.v
add_file ../src/ddr3fb/pll_hdmi.v
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
add_file ../src/rtl/uart_beacon.sv
add_file -type cst diag/fb_selftest.cst
add_file -type sdc diag/fb_selftest.sdc
run all

// Gowin PLLA: 50 MHz in -> 100 MHz out, for the SDRAM controller/memtest.
// VCO = 50 * MDIV(20) / IDIV(1) = 1000 MHz (inside the GW5A 700-1400 window);
// CLKOUT0 = VCO/ODIV0(10) = 100 MHz. The MiSTer MCR-3 SDRAM controller's
// refresh (RFRSH_CYCLES) is sized for ~100-108 MHz, so 100 MHz keeps refresh
// within the 7.8 us row requirement.
module gowin_pll_sdram (
    input  clkin,
    output clk100,
    output lock
);

wire clkout1_o, clkout2_o, clkout3_o, clkout4_o, clkout5_o, clkout6_o;
wire clkfbout_o;
wire [7:0] mdrdo_o;
wire gw_gnd = 1'b0;

PLLA PLLA_inst (
    .LOCK(lock),
    .CLKOUT0(clk100),   // 100 MHz
    .CLKOUT1(clkout1_o),
    .CLKOUT2(clkout2_o),
    .CLKOUT3(clkout3_o),
    .CLKOUT4(clkout4_o),
    .CLKOUT5(clkout5_o),
    .CLKOUT6(clkout6_o),
    .CLKFBOUT(clkfbout_o),
    .MDRDO(mdrdo_o),
    .CLKIN(clkin),
    .CLKFB(gw_gnd),
    .RESET(gw_gnd),
    .PLLPWD(gw_gnd),
    .RESET_I(gw_gnd),
    .RESET_O(gw_gnd),
    .PSSEL({gw_gnd,gw_gnd,gw_gnd}),
    .PSDIR(gw_gnd),
    .PSPULSE(gw_gnd),
    .SSCPOL(gw_gnd),
    .SSCON(gw_gnd),
    .SSCMDSEL({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
    .SSCMDSEL_FRAC({gw_gnd,gw_gnd,gw_gnd}),
    .MDCLK(gw_gnd),
    .MDOPC({gw_gnd,gw_gnd}),
    .MDAINC(gw_gnd),
    .MDWDI({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd})
);

defparam PLLA_inst.FCLKIN = "50";
defparam PLLA_inst.IDIV_SEL = 1;
defparam PLLA_inst.FBDIV_SEL = 1;
defparam PLLA_inst.CLKFB_SEL = "INTERNAL";
defparam PLLA_inst.ODIV0_SEL = 10;
defparam PLLA_inst.ODIV0_FRAC_SEL = 0;
defparam PLLA_inst.ODIV1_SEL = 8;
defparam PLLA_inst.ODIV2_SEL = 8;
defparam PLLA_inst.ODIV3_SEL = 8;
defparam PLLA_inst.ODIV4_SEL = 8;
defparam PLLA_inst.ODIV5_SEL = 8;
defparam PLLA_inst.ODIV6_SEL = 8;
defparam PLLA_inst.MDIV_SEL = 20;
defparam PLLA_inst.MDIV_FRAC_SEL = 0;
defparam PLLA_inst.ODIV0_FRAC_SEL = 0;
defparam PLLA_inst.DYN_DPA_EN = "false";
defparam PLLA_inst.DYN_PE0_SEL = "false";
defparam PLLA_inst.DYN_PE1_SEL = "false";
defparam PLLA_inst.DYN_PE2_SEL = "false";

endmodule

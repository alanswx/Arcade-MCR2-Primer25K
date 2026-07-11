// DVI/HDMI Transmitter for Gowin GW5A FPGAs
module hdmi_tx (
    input            clk_pixel,      // Pixel clock (e.g. 74.25 MHz)
    input            clk_5x_pixel,   // 5x Pixel clock (e.g. 371.25 MHz)
    input            resetn,
    input      [7:0] rgb_r,          // Red channel data (8-bit)
    input      [7:0] rgb_g,          // Green channel data (8-bit)
    input      [7:0] rgb_b,          // Blue channel data (8-bit)
    input            de,             // Data enable (active video)
    input            hsync,          // Horizontal sync
    input            vsync,          // Vertical sync

    // Physical HDMI differential outputs
    output           tmds_clk_p,
    output           tmds_clk_n,
    output     [2:0] tmds_d_p,
    output     [2:0] tmds_d_n
);

// 10-bit encoded TMDS symbols
wire [9:0] tmds_red;
wire [9:0] tmds_green;
wire [9:0] tmds_blue;

// Instantiation of TMDS Encoders
// Blue channel encodes HSync and VSync on control bits [1:0]
tmds_encoder encode_blue (
    .clk(clk_pixel),
    .resetn(resetn),
    .de(de),
    .ctrl({vsync, hsync}),
    .din(rgb_b),
    .dout(tmds_blue)
);

// Green channel encodes 2'b00
tmds_encoder encode_green (
    .clk(clk_pixel),
    .resetn(resetn),
    .de(de),
    .ctrl(2'b00),
    .din(rgb_g),
    .dout(tmds_green)
);

// Red channel encodes 2'b00
tmds_encoder encode_red (
    .clk(clk_pixel),
    .resetn(resetn),
    .de(de),
    .ctrl(2'b00),
    .din(rgb_r),
    .dout(tmds_red)
);

// Explicit instantiation of OSER10 primitives to bypass any Gowin array-of-instance compiler bugs
wire [2:0] tmds_d;
OSER10 tmds_serdes_blue (
    .Q(tmds_d[0]),
    .D0(tmds_blue[0]),
    .D1(tmds_blue[1]),
    .D2(tmds_blue[2]),
    .D3(tmds_blue[3]),
    .D4(tmds_blue[4]),
    .D5(tmds_blue[5]),
    .D6(tmds_blue[6]),
    .D7(tmds_blue[7]),
    .D8(tmds_blue[8]),
    .D9(tmds_blue[9]),
    .PCLK(clk_pixel),
    .FCLK(clk_5x_pixel),
    .RESET(~resetn)
);

OSER10 tmds_serdes_green (
    .Q(tmds_d[1]),
    .D0(tmds_green[0]),
    .D1(tmds_green[1]),
    .D2(tmds_green[2]),
    .D3(tmds_green[3]),
    .D4(tmds_green[4]),
    .D5(tmds_green[5]),
    .D6(tmds_green[6]),
    .D7(tmds_green[7]),
    .D8(tmds_green[8]),
    .D9(tmds_green[9]),
    .PCLK(clk_pixel),
    .FCLK(clk_5x_pixel),
    .RESET(~resetn)
);

OSER10 tmds_serdes_red (
    .Q(tmds_d[2]),
    .D0(tmds_red[0]),
    .D1(tmds_red[1]),
    .D2(tmds_red[2]),
    .D3(tmds_red[3]),
    .D4(tmds_red[4]),
    .D5(tmds_red[5]),
    .D6(tmds_red[6]),
    .D7(tmds_red[7]),
    .D8(tmds_red[8]),
    .D9(tmds_red[9]),
    .PCLK(clk_pixel),
    .FCLK(clk_5x_pixel),
    .RESET(~resetn)
);

// Output differential TMDS buffers using Gowin ELVDS_OBUF blocks
ELVDS_OBUF tmds_bufds [3:0] (
    .I({clk_pixel, tmds_d}),
    .O({tmds_clk_p, tmds_d_p}),
    .OB({tmds_clk_n, tmds_d_n})
);

endmodule

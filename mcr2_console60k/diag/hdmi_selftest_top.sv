// Minimal HDMI self-test for the Tang Console 60K.
// No DDR3, no framebuffer, no core: just 640x480@60 colour bars through the
// original OSER10/ELVDS path (src/dvi_tx). If this syncs, the board, cable
// and monitor are fine and the fault is specific to the DDR3 framebuffer's
// HDMI stack. If it does NOT sync, the problem is more fundamental.
// Beacon still runs so there is a heartbeat either way.
module hdmi_selftest_top (
    input        sys_clk,
    input        s1,
    output       tmds_clk_p, tmds_clk_n,
    output [2:0] tmds_d_p,   tmds_d_n,
    output       uart_tx
);

wire clk_sys, clk_p5, clk50, locked;
gowin_pll_mcr2 pll (.clkin(sys_clk), .clk_sys(clk_sys), .clk_p5(clk_p5),
                    .clk_50(clk50), .lock(locked));

wire clk_pixel;                       // 25 MHz = 125/5
CLKDIV div (.CLKOUT(clk_pixel), .HCLKIN(clk_p5), .RESETN(locked), .CALIB(1'b0));
defparam div.DIV_MODE = "5";

// 640x480@60: 800x525 total, both syncs active low
reg [9:0] hc = 0, vc = 0;
always @(posedge clk_pixel) begin
    if (hc == 799) begin
        hc <= 0;
        vc <= (vc == 524) ? 10'd0 : vc + 10'd1;
    end else hc <= hc + 10'd1;
end
wire de = (hc < 640) && (vc < 480);
wire hs = ~((hc >= 656) && (hc < 752));
wire vs = ~((vc >= 490) && (vc < 492));

wire [7:0] r = de ? {hc[8:6], 5'b0} : 8'd0;
wire [7:0] g = de ? {hc[5:3], 5'b0} : 8'd0;
wire [7:0] b = de ? {vc[6:4], 5'b0} : 8'd0;

hdmi_tx tx (
    .clk_pixel(clk_pixel), .clk_5x_pixel(clk_p5), .resetn(1'b1),
    .rgb_r(r), .rgb_g(g), .rgb_b(b), .de(de), .hsync(hs), .vsync(vs),
    .tmds_clk_p(tmds_clk_p), .tmds_clk_n(tmds_clk_n),
    .tmds_d_p(tmds_d_p),     .tmds_d_n(tmds_d_n)
);

// heartbeat on the pixel clock so the beacon proves this design is live
reg [25:0] hb = 0;
always @(posedge clk_pixel) hb <= hb + 1'b1;
uart_beacon #(.CLK_HZ(40_000_000)) beacon (
    .clk(clk_sys), .calib(locked), .ddr_rst(1'b0),
    .cnt_x(hb[25:10]), .cnt_q(8'hAA), .aux(8'h5E), .aux2(8'h5E), .txd(uart_tx)
);
endmodule

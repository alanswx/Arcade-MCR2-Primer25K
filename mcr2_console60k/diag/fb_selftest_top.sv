// Minimal DDR3-framebuffer HDMI self-test: pll_27 + ddr3_framebuffer + a
// generated pattern. No MCR core, no USB host, no SD loader, no analog video.
//
// This is the counterpart to hdmi_selftest (which proved our own dvi_tx
// encoder works on these pins at 640x480). If THIS displays, the gbatang
// stack is fine and our full design's congestion is what breaks it. If this
// is also black, the stack itself does not work in this environment and the
// pragmatic answer is to drive HDMI from dvi_tx instead.
module fb_selftest_top (
    input        sys_clk,
    input        s1,
    output [14:0] ddr_addr,
    output [2:0]  ddr_bank,
    output        ddr_cs, ddr_ras, ddr_cas, ddr_we,
    output        ddr_ck, ddr_ck_n, ddr_cke, ddr_odt, ddr_reset_n,
    output [1:0]  ddr_dm,
    inout  [15:0] ddr_dq,
    inout  [1:0]  ddr_dqs, ddr_dqs_n,
    output       tmds_clk_p, tmds_clk_n,
    output [2:0] tmds_d_p,   tmds_d_n,
    output       hpd_en,
    output       uart_tx
);

assign hpd_en = 1'b1;

wire clk_sys, clk_p5, clk50, locked;
gowin_pll_mcr2 pll (.clkin(sys_clk), .clk_sys(clk_sys), .clk_p5(clk_p5),
                    .clk_50(clk50), .lock(locked));
wire clk27;
pll_27 pll27 (.clkin(sys_clk), .clkout0(clk27));

reg [7:0] rst_cnt = 255;
wire rst = (rst_cnt != 0);
always @(posedge clk_sys) if (rst_cnt != 0) rst_cnt <= rst_cnt - 8'd1;

// stream a 512x480 pattern into the framebuffer, one pixel per clk_sys
reg [9:0] px = 0, py = 0;
reg vsync = 0;
always @(posedge clk_sys) begin
    vsync <= 1'b0;
    if (px == 10'd511) begin
        px <= 0;
        if (py == 10'd479) begin py <= 0; vsync <= 1'b1; end
        else py <= py + 10'd1;
    end else px <= px + 10'd1;
end
// colour bars + a moving-ish grid so a wrong stride is obvious
wire [11:0] pattern = {px[8:5], py[8:5], (px[3:0] ^ py[3:0])};

wire fb_hclk, fb_calib, fb_ddr_rst, fb_clkx1;
ddr3_framebuffer #(.WIDTH(512), .HEIGHT(480), .COLOR_BITS(12),
                   .PREFETCH_DELAY(44), .DVI_MODE(0)) fb (
    .hclk_dbg(fb_hclk),
    .clk_27(clk27), .pll_lock_27(1'b1), .clk_g(clk50),
    .clk_out(fb_clkx1), .rst_n(~rst), .ddr_rst(fb_ddr_rst),
    .init_calib_complete(fb_calib), .ddr_prefetch_delay(6'd44),
    .clk(clk_sys), .fb_width(11'd512), .fb_height(10'd480),
    .disp_width(11'd960), .fb_vsync(vsync), .fb_we(1'b1), .fb_data(pattern),
    .sound_left(16'd0), .sound_right(16'd0),
    .ddr_addr(ddr_addr), .ddr_bank(ddr_bank), .ddr_cs(ddr_cs),
    .ddr_ras(ddr_ras), .ddr_cas(ddr_cas), .ddr_we(ddr_we),
    .ddr_ck(ddr_ck), .ddr_ck_n(ddr_ck_n), .ddr_cke(ddr_cke),
    .ddr_odt(ddr_odt), .ddr_reset_n(ddr_reset_n), .ddr_dm(ddr_dm),
    .ddr_dq(ddr_dq), .ddr_dqs(ddr_dqs), .ddr_dqs_n(ddr_dqs_n),
    .tmds_clk_p(tmds_clk_p), .tmds_clk_n(tmds_clk_n),
    .tmds_d_p(tmds_d_p), .tmds_d_n(tmds_d_n)
);

reg [24:0] hb = 0;
always @(posedge fb_hclk) hb <= hb + 1'b1;
uart_beacon #(.CLK_HZ(40_000_000)) beacon (
    .clk(clk_sys), .calib(fb_calib), .ddr_rst(fb_ddr_rst),
    .cnt_x({hb[24:21], 12'h000}), .cnt_q(8'hFB), .aux(8'hFB), .aux2(8'hFB),
    .txd(uart_tx)
);
endmodule

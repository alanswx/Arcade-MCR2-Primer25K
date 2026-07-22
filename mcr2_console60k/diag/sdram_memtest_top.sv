// SDRAM module self-test for the Tang Console 60K.
//
// Purpose (roadmap Phase B): verify the Tang SDRAM module in J9 - pins,
// clock phase, chip timing - IN ISOLATION, using the exact controller MCR-3
// will use (src/rtl/sdram_gw.sv = MiSTer MCR-3 controller, Gowin clock swap),
// so that when a core later rides on SDRAM a fault can be attributed to the
// core, not the memory.
//
// At power-on it sweeps 1M words (2 MB): write a per-address pattern, read it
// all back, compare. Result shows on:
//   - the four J10 status LEDs (debug_o): see the mapping below;
//   - the UART beacon (U15 -> USB-C serial, 115200): while running, x climbs
//     with the address; on finish c1=PASS/c0=FAIL, and on failure q/d carry
//     the first bad address and data.
//
// SDRAM pin names match docs/pinrefs/snestang_console.cst (nand2mario's
// convention) so that constraint file's SDRAM block drops straight in.
module sdram_memtest_top (
    input        sys_clk,     // 50 MHz (V22)
    input        s1,          // user key AA13 - active low (reset)

    // Tang SDRAM module (J9). CKE is tied high on the module (no FPGA pin).
    inout  [15:0] O_sdram_dq_io,  // named IO_sdram_dq in the CST alias below
    output [12:0] O_sdram_addr,
    output [1:0]  O_sdram_ba,
    output [1:0]  O_sdram_dqm,
    output        O_sdram_clk,
    output        O_sdram_cs_n,
    output        O_sdram_wen_n,
    output        O_sdram_ras_n,
    output        O_sdram_cas_n,

    output [3:0] debug_o,     // J10 21-24 status LEDs
    output       uart_tx      // U15 beacon
);

// keep the HDMI dock enable untouched; this test drives no video
wire clk100, pll_locked;
gowin_pll_sdram pll_inst (.clkin(sys_clk), .clk100(clk100), .lock(pll_locked));

wire key_s1 = ~s1;

// power-on reset: hold ~1 ms after lock so the controller's own 100 us init
// window is clean, then release once.
reg [15:0] rst_cnt = 16'hFFFF;
wire rst = (rst_cnt != 0) || !pll_locked;
always @(posedge clk100) begin
    if (!pll_locked || key_s1) rst_cnt <= 16'hFFFF;
    else if (rst_cnt != 0)     rst_cnt <= rst_cnt - 16'd1;
end

// --- memtest <-> controller port1 ---
wire        p1_req, p1_ack, p1_we;
wire [23:1] p1_a;
wire [1:0]  p1_ds;
wire [15:0] p1_d, p1_q;

wire        mt_done, mt_pass, mt_phase;
wire [23:1] mt_erra, mt_cur;
wire [15:0] mt_exp, mt_got;

sdram_memtest #(.LAST_ADDR(23'h0F_FFFF)) memtest (
    .clk(clk100), .rst(rst),
    .p1_req(p1_req), .p1_ack(p1_ack), .p1_we(p1_we),
    .p1_a(p1_a), .p1_ds(p1_ds), .p1_d(p1_d), .p1_q(p1_q),
    .done(mt_done), .pass(mt_pass), .err_addr(mt_erra),
    .err_exp(mt_exp), .err_got(mt_got), .cur_addr(mt_cur), .phase_rd(mt_phase)
);

// controller: only port1 is exercised; the CPU/sprite read ports and port2
// are tied off (their outputs unused).
wire        sdram_cke_unused;
sdram_gw sdram (
    .SDRAM_DQ(O_sdram_dq_io),
    .SDRAM_A(O_sdram_addr),
    .SDRAM_DQML(O_sdram_dqm[0]),
    .SDRAM_DQMH(O_sdram_dqm[1]),
    .SDRAM_BA(O_sdram_ba),
    .SDRAM_nCS(O_sdram_cs_n),
    .SDRAM_nWE(O_sdram_wen_n),
    .SDRAM_nRAS(O_sdram_ras_n),
    .SDRAM_nCAS(O_sdram_cas_n),
    .SDRAM_CKE(sdram_cke_unused),   // no board pin; module ties CKE high
    .SDRAM_CLK(O_sdram_clk),

    .init_n(~rst),
    .clk(clk100),

    .port1_req(p1_req), .port1_ack(p1_ack), .port1_we(p1_we),
    .port1_a(p1_a), .port1_ds(p1_ds), .port1_d(p1_d), .port1_q(p1_q),

    .cpu1_addr(23'd0), .cpu1_q(),
    .cpu2_addr(23'd0), .cpu2_q(),
    .cpu3_addr(23'd0), .cpu3_q(),

    .port2_req(1'b0), .port2_ack(), .port2_we(1'b0),
    .port2_a(23'd0), .port2_ds(2'b00), .port2_d(16'd0), .port2_q(),

    .sp_addr(22'd0), .sp_q()
);

// --- status LEDs (probe vs GND with a DMM, or wire real LEDs) ---
//   debug_o[0]: PASS       - steady HIGH only after done && pass
//   debug_o[1]: DONE       - HIGH once the sweep finished
//   debug_o[2]: FAIL       - HIGH once done && !pass (a real fault)
//   debug_o[3]: heartbeat  - ~1.5 Hz from clk100; frozen = clock/PLL dead
reg [26:0] hb = 0;
always @(posedge clk100) hb <= hb + 27'd1;
assign debug_o[0] = mt_done &  mt_pass;
assign debug_o[1] = mt_done;
assign debug_o[2] = mt_done & ~mt_pass;
assign debug_o[3] = hb[26];

// --- UART beacon ---
// c = pass, r = done; while running x tracks the address (climbing = alive),
// on failure q = err_addr[15:8], d = err_got[7:0]; L nibbles: phase + flags.
uart_beacon #(.CLK_HZ(100_000_000), .BAUD(115200)) beacon (
    .clk(clk100),
    .calib(mt_pass),
    .ddr_rst(mt_done),
    .cnt_x(mt_done ? mt_erra[16:1] : mt_cur[16:1]),
    .cnt_q(mt_done ? mt_erra[23:17] + 8'd0 : 8'h00),
    .aux(mt_got[7:0]),
    .aux2({hb[26], mt_phase, mt_done, mt_pass, mt_exp[3:0]}),
    .txd(uart_tx)
);

endmodule

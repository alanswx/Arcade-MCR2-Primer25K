// Testbench: sdram_memtest against the behavioural port model.
//   Instance A: clean memory  -> must finish with pass=1.
//   Instance B: one word corrupted on write -> must finish pass=0 with
//               err_addr pointing at exactly that word.
// Validates the FSM's handshake, sweep, compare and failure-latch logic.
module tb_sdram_memtest;

localparam [23:1] LAST = 23'd255;      // 256 words - fast sim
localparam integer BAD = 42;

logic clk = 0, rst = 1;
always #5 clk = ~clk;                  // 100 MHz

int errors = 0;

// ---- instance A: clean ----
wire        a_req, a_we, a_done, a_pass, a_phase;
wire [23:1] a_a, a_erra, a_cur;
wire [1:0]  a_ds;
wire [15:0] a_d, a_q, a_exp, a_got;
wire        a_ack;

sdram_memtest #(.LAST_ADDR(LAST)) a_dut (
    .clk(clk), .rst(rst),
    .p1_req(a_req), .p1_ack(a_ack), .p1_we(a_we), .p1_a(a_a),
    .p1_ds(a_ds), .p1_d(a_d), .p1_q(a_q),
    .done(a_done), .pass(a_pass), .err_addr(a_erra),
    .err_exp(a_exp), .err_got(a_got), .cur_addr(a_cur), .phase_rd(a_phase)
);
sdram_port_model #(.CORRUPT_ADDR(-1)) a_mem (
    .clk(clk), .p1_req(a_req), .p1_ack(a_ack), .p1_we(a_we),
    .p1_a(a_a), .p1_ds(a_ds), .p1_d(a_d), .p1_q(a_q)
);

// ---- instance B: one corrupted word ----
wire        b_req, b_we, b_done, b_pass, b_phase;
wire [23:1] b_a, b_erra, b_cur;
wire [1:0]  b_ds;
wire [15:0] b_d, b_q, b_exp, b_got;
wire        b_ack;

sdram_memtest #(.LAST_ADDR(LAST)) b_dut (
    .clk(clk), .rst(rst),
    .p1_req(b_req), .p1_ack(b_ack), .p1_we(b_we), .p1_a(b_a),
    .p1_ds(b_ds), .p1_d(b_d), .p1_q(b_q),
    .done(b_done), .pass(b_pass), .err_addr(b_erra),
    .err_exp(b_exp), .err_got(b_got), .cur_addr(b_cur), .phase_rd(b_phase)
);
sdram_port_model #(.CORRUPT_ADDR(BAD)) b_mem (
    .clk(clk), .p1_req(b_req), .p1_ack(b_ack), .p1_we(b_we),
    .p1_a(b_a), .p1_ds(b_ds), .p1_d(b_d), .p1_q(b_q)
);

int t;
initial begin
    repeat (5) @(posedge clk);
    rst = 0;

    t = 0;
    while (!(a_done && b_done) && t < 2_000_000) begin @(posedge clk); t++; end

    if (!a_done || !b_done) begin
        $display("FAIL: memtest did not finish (t=%0d)", t);
        errors++;
    end

    if (!a_pass) begin
        $display("FAIL: clean memory reported a fault at %0d", a_erra);
        errors++;
    end else
        $display("  clean memory: PASS in %0d clk", t);

    if (b_pass) begin
        $display("FAIL: corrupted memory reported PASS");
        errors++;
    end else if (b_erra !== BAD[23:1]) begin
        $display("FAIL: corruption flagged at %0d, expected %0d", b_erra, BAD);
        errors++;
    end else
        $display("  corrupted word correctly caught at addr %0d (exp %04x got %04x)",
                 b_erra, b_exp, b_got);

    if (errors == 0) $display("PASS: sdram_memtest");
    else             $display("FAIL: sdram_memtest (%0d errors)", errors);
    $finish;
end

endmodule

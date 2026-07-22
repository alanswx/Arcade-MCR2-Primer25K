// SDRAM memtest: writes a per-address pattern to every word in [0..LAST_ADDR],
// then reads it all back and compares. Drives port1 of sdram_gw via its toggle
// handshake (flip req, wait for ack==req). One-shot at boot; the result lands
// on the status LEDs and the UART beacon so the Tang SDRAM module can be
// verified in isolation before a core depends on it.
//
// The pattern mixes low and high address bits, so a stuck data bit, a swapped
// data line, AND an address-decode/aliasing fault all surface (a word read
// back from the wrong row returns a different pattern). First failure is
// latched (address + expected + got) for the beacon.
module sdram_memtest #(
    // default: 1M words = 2 MB swept (spans many rows/banks); raise for a
    // fuller sweep. Kept modest so the whole test is a few hundred ms.
    parameter [23:1] LAST_ADDR = 23'h0F_FFFF
)(
    input             clk,
    input             rst,

    // sdram_gw port1
    output reg        p1_req,
    input             p1_ack,
    output reg        p1_we,
    output reg [23:1] p1_a,
    output reg [1:0]  p1_ds,
    output reg [15:0] p1_d,
    input      [15:0] p1_q,

    // results (valid once `done`)
    output reg        done,
    output reg        pass,        // 1 = all words matched
    output reg [23:1] err_addr,    // first mismatch
    output reg [15:0] err_exp,
    output reg [15:0] err_got,
    output reg [23:1] cur_addr,    // live progress
    output reg        phase_rd     // 0 = writing, 1 = reading
);

// unique-ish 16-bit value per word address
function [15:0] patt(input [23:1] a);
    patt = ({a[8:1], a[16:9]} ^ {a[23:17], 9'd0}) ^ 16'hA5C3;
endfunction

localparam [2:0] S_START = 3'd0,
                 S_WR    = 3'd1,
                 S_WR_W  = 3'd2,
                 S_RD    = 3'd3,
                 S_RD_W  = 3'd4,
                 S_DONE  = 3'd5;
reg [2:0] st;

always @(posedge clk) begin
    if (rst) begin
        st       <= S_START;
        p1_req   <= 1'b0;
        p1_we    <= 1'b0;
        p1_ds    <= 2'b11;
        p1_a     <= 23'd0;
        p1_d     <= 16'd0;
        done     <= 1'b0;
        pass     <= 1'b1;
        cur_addr <= 23'd0;
        phase_rd <= 1'b0;
        err_addr <= 23'd0;
        err_exp  <= 16'd0;
        err_got  <= 16'd0;
    end else begin
        case (st)
        S_START: begin
            cur_addr <= 23'd0;
            pass     <= 1'b1;
            phase_rd <= 1'b0;
            st       <= S_WR;
        end

        // --- write patt(cur) at cur ---
        S_WR: begin
            p1_a   <= cur_addr;
            p1_d   <= patt(cur_addr);
            p1_we  <= 1'b1;
            p1_ds  <= 2'b11;
            p1_req <= ~p1_req;      // launch (toggle)
            st     <= S_WR_W;
        end
        S_WR_W: if (p1_ack == p1_req) begin
            if (cur_addr == LAST_ADDR) begin
                cur_addr <= 23'd0;
                phase_rd <= 1'b1;
                st       <= S_RD;
            end else begin
                cur_addr <= cur_addr + 23'd1;
                st       <= S_WR;
            end
        end

        // --- read back and compare ---
        S_RD: begin
            p1_a   <= cur_addr;
            p1_we  <= 1'b0;
            p1_ds  <= 2'b11;
            p1_req <= ~p1_req;
            st     <= S_RD_W;
        end
        S_RD_W: if (p1_ack == p1_req) begin
            if (pass && p1_q != patt(cur_addr)) begin
                pass     <= 1'b0;      // sticky; latch first failure
                err_addr <= cur_addr;
                err_exp  <= patt(cur_addr);
                err_got  <= p1_q;
            end
            if (cur_addr == LAST_ADDR) st <= S_DONE;
            else begin
                cur_addr <= cur_addr + 23'd1;
                st       <= S_RD;
            end
        end

        S_DONE: done <= 1'b1;

        default: st <= S_DONE;
        endcase
    end
end

endmodule

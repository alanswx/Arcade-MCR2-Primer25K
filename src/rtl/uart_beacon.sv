// Minimal one-way UART status beacon for closed-case debugging.
// Prints a fixed-format status line roughly twice a second, e.g.:
//   "FB c1 r0 xA31F q7C\r\n"
//     c : init_calib_complete (1 = DDR3 trained)
//     r : ddr_rst             (0 = DDR PLL settled)
//     x : 16-bit sample of a counter running on clk_x1 (74.25 MHz pixel
//         clock) - if this value is frozen between lines, clk_x1 is dead
//     q : 8-bit sample of a counter running on the 27 MHz reference -
//         frozen means the 27 MHz PLL chain is dead
// 115200 8N1. The counters are sampled asynchronously (debug only).
module uart_beacon #(
    parameter CLK_HZ = 40_000_000,
    parameter BAUD   = 115200
) (
    input             clk,
    input             calib,
    input             ddr_rst,
    input      [15:0] cnt_x,
    input      [7:0]  cnt_q,
    input      [7:0]  aux,      // free-form status byte, printed as "dXX"
    output reg        txd = 1'b1
);

localparam DIV = CLK_HZ / BAUD;            // 347 @ 40 MHz
localparam MSG_LEN = 24;
localparam GAP_CYCLES = CLK_HZ / 2;        // ~0.5 s between lines

function [7:0] hexchar(input [3:0] n);
    hexchar = (n < 10) ? (8'h30 + n) : (8'h41 + n - 10);
endfunction

// Latched-at-line-start copies so one line is internally consistent
reg        l_calib, l_rst;
reg [15:0] l_x;
reg [7:0]  l_q;
reg [7:0]  l_aux;

reg [8:0]  baud_cnt = 0;
reg [3:0]  bit_idx  = 0;   // 0 = start, 1..8 = data, 9 = stop
reg [4:0]  char_idx = 0;
reg [24:0] gap_cnt  = 0;
reg        sending  = 0;

reg [7:0] cur;
always @(*) begin
    case (char_idx)
        5'd0:  cur = "F";
        5'd1:  cur = "B";
        5'd2:  cur = " ";
        5'd3:  cur = "c";
        5'd4:  cur = l_calib ? "1" : "0";
        5'd5:  cur = " ";
        5'd6:  cur = "r";
        5'd7:  cur = l_rst ? "1" : "0";
        5'd8:  cur = " ";
        5'd9:  cur = "x";
        5'd10: cur = hexchar(l_x[15:12]);
        5'd11: cur = hexchar(l_x[11:8]);
        5'd12: cur = hexchar(l_x[7:4]);
        5'd13: cur = hexchar(l_x[3:0]);
        5'd14: cur = " ";
        5'd15: cur = "q";
        5'd16: cur = hexchar(l_q[7:4]);
        5'd17: cur = hexchar(l_q[3:0]);
        5'd18: cur = " ";
        5'd19: cur = "d";
        5'd20: cur = hexchar(l_aux[7:4]);
        5'd21: cur = hexchar(l_aux[3:0]);
        5'd22: cur = 8'h0D;
        5'd23: cur = 8'h0A;
        default: cur = " ";
    endcase
end

always @(posedge clk) begin
    if (!sending) begin
        txd <= 1'b1;
        gap_cnt <= gap_cnt + 1'b1;
        if (gap_cnt == GAP_CYCLES) begin
            gap_cnt  <= 0;
            sending  <= 1'b1;
            char_idx <= 0;
            bit_idx  <= 0;
            baud_cnt <= 0;
            l_calib  <= calib;
            l_rst    <= ddr_rst;
            l_x      <= cnt_x;
            l_q      <= cnt_q;
            l_aux    <= aux;
        end
    end else begin
        if (baud_cnt == DIV - 1) begin
            baud_cnt <= 0;
            if (bit_idx == 4'd9) begin
                bit_idx <= 0;
                if (char_idx == MSG_LEN - 1) sending <= 1'b0;
                else char_idx <= char_idx + 1'b1;
            end else begin
                bit_idx <= bit_idx + 1'b1;
            end
        end else begin
            baud_cnt <= baud_cnt + 1'b1;
        end

        case (bit_idx)
            4'd0:    txd <= 1'b0;                 // start bit
            4'd9:    txd <= 1'b1;                 // stop bit
            default: txd <= cur[bit_idx - 1];     // data bits, LSB first
        endcase
    end
end

endmodule

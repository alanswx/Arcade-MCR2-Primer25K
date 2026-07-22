// Behavioural stand-in for sdram_gw's port1, for simulation only. Implements
// the toggle handshake (ack follows req when a transaction completes, after a
// few cycles' latency) over a sparse memory. This validates the memtest FSM's
// use of the port contract; the controller itself is upstream-proven and its
// Gowin clock swap is a hardware-only concern.
//
// CORRUPT_ADDR >= 0 flips bit 0 on WRITE to that address, so the readback
// mismatches - exercising the memtest's failure-latch path.
module sdram_port_model #(
    parameter integer CORRUPT_ADDR = -1
)(
    input             clk,
    input             p1_req,
    output reg        p1_ack,
    input             p1_we,
    input      [23:1] p1_a,
    input      [1:0]  p1_ds,
    input      [15:0] p1_d,
    output reg [15:0] p1_q
);

logic [15:0] mem [int];
reg   state = 1'b0;
reg [2:0] lat = 3'd0;

initial begin
    p1_ack = 1'b0;
    p1_q   = 16'd0;
end

always @(posedge clk) begin
    if (p1_req ^ state) begin        // a request is pending
        if (lat == 3'd0) begin
            if (p1_we) begin
                logic [15:0] v;
                v = p1_d;
                if (CORRUPT_ADDR >= 0 && p1_a == CORRUPT_ADDR[23:1])
                    v = v ^ 16'h0001;         // inject a stuck bit
                mem[p1_a] = v;
            end else begin
                p1_q <= mem.exists(p1_a) ? mem[p1_a] : 16'h0000;
            end
            p1_ack <= p1_req;
            state  <= p1_req;
            lat    <= 3'd4;
        end else begin
            lat <= lat - 3'd1;
        end
    end else begin
        lat <= 3'd4;                  // ready for the next request
    end
end

endmodule

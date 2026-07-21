// Loads a game's ROM image from SD into the core's memories at boot.
//
// Card layout (written by tools/make_rompack.py, raw sectors - no filesystem):
//   sector PACK_BASE            header: "MCRPACK1" + slot count
//   sector PACK_BASE+1 + N*256  slot N payload, 128 KB
//
// Payload layout == the core's download address map:
//   0x00000-0x0FFFF  CPU program ROM   (64 KB)
//   0x10000-0x13FFF  sound CPU ROM     (16 KB)
//   0x14000-0x1BFFF  sprite gfx2       (32 KB)
//   0x1C000-0x1DFFF  background gfx1_1 ( 8 KB)
//   0x1E000-0x1FFFF  background gfx1_2 ( 8 KB)
//
// The core must be held in reset until `done` rises. `error` means the card
// is missing/unreadable or holds no valid pack - the caller should surface
// that (status LED / test pattern) rather than sit on a black screen.
module rom_loader #(
    parameter [31:0] PACK_BASE   = 32'd2048,   // first sector of the pack
    parameter int    SLOT_SECTORS = 256        // 128 KB per slot
)(
    input             clk,
    input             rst,
    input      [3:0]  slot,          // game select (from the DIP switches)

    // sd_reader interface
    input             sd_ready,
    input             sd_err,
    output reg        sd_rd_start,
    output reg [31:0] sd_sector,
    input      [7:0]  sd_dout,
    input             sd_dout_valid,
    input             sd_rd_done,

    // ROM download bus (see map above)
    output reg [16:0] dl_addr,
    output reg [7:0]  dl_data,
    output reg        dl_wr,

    output reg        done,
    output reg        error
);

localparam [2:0]
    L_WAIT   = 3'd0,   // wait for the card to come up
    L_HDR    = 3'd1,   // read and check the pack header
    L_HDRCHK = 3'd2,
    L_DATA   = 3'd3,   // stream the slot payload
    L_NEXT   = 3'd4,
    L_DONE   = 3'd5,
    L_ERR    = 3'd6;

// "MCRPACK1"
localparam [63:0] MAGIC = 64'h4D_43_52_50_41_43_4B_31;

reg [2:0]  st;
reg [26:0] watchdog;     // hard upper bound on the whole load (~1.7s @40MHz)
reg [63:0] hdr;
reg [7:0]  slot_cnt;     // header byte 8: number of slots in the pack
reg [8:0]  hdr_cnt;
reg [8:0]  sect_left_hi;   // sectors remaining in this slot (0..256)
reg [31:0] sector;
reg [16:0] addr;

always @(posedge clk) begin
    sd_rd_start <= 1'b0;
    dl_wr       <= 1'b0;

    if (rst) begin
        st       <= L_WAIT;
        done     <= 1'b0;
        error    <= 1'b0;
        addr     <= 17'd0;
        hdr_cnt  <= 9'd0;
        hdr      <= 64'd0;
        watchdog <= 27'd0;
    end else begin
        // Nothing here may hang: a card that answers but then stops mid
        // transfer would otherwise leave the game core in reset forever.
        if (st != L_DONE && st != L_ERR) begin
            watchdog <= watchdog + 27'd1;
            if (watchdog == 27'h7FF_FFFF) st <= L_ERR;
        end

        case (st)

        L_WAIT: begin
            if (sd_err) st <= L_ERR;
            else if (sd_ready) begin
                sd_sector   <= PACK_BASE;
                sd_rd_start <= 1'b1;
                hdr_cnt     <= 9'd0;
                st          <= L_HDR;
            end
        end

        // capture the first 8 bytes of the header sector
        L_HDR: begin
            if (sd_err) st <= L_ERR;
            else begin
                if (sd_dout_valid) begin
                    if (hdr_cnt < 9'd8) hdr <= {hdr[55:0], sd_dout};
                    if (hdr_cnt == 9'd8) slot_cnt <= sd_dout;
                    hdr_cnt <= hdr_cnt + 9'd1;
                end
                if (sd_rd_done) st <= L_HDRCHK;
            end
        end

        L_HDRCHK: begin
            if (hdr != MAGIC) begin
                st <= L_ERR;            // blank or foreign card
            end else if ({4'd0, slot} >= slot_cnt) begin
                st <= L_ERR;            // pack has no such slot - loading it
                                        // would stream zeros over the ROMs
            end else begin
                sector       <= PACK_BASE + 32'd1 + (slot * SLOT_SECTORS);
                sect_left_hi <= 9'(SLOT_SECTORS);
                addr         <= 17'd0;
                st           <= L_NEXT;
            end
        end

        // request the next sector of the payload
        L_NEXT: begin
            if (sect_left_hi == 9'd0) begin
                st   <= L_DONE;
                done <= 1'b1;
            end else begin
                sd_sector   <= sector;
                sd_rd_start <= 1'b1;
                st          <= L_DATA;
            end
        end

        // stream its bytes onto the download bus
        L_DATA: begin
            if (sd_err) st <= L_ERR;
            else begin
                if (sd_dout_valid) begin
                    dl_addr <= addr;
                    dl_data <= sd_dout;
                    dl_wr   <= 1'b1;
                    addr    <= addr + 17'd1;
                end
                if (sd_rd_done) begin
                    sector       <= sector + 32'd1;
                    sect_left_hi <= sect_left_hi - 9'd1;
                    st           <= L_NEXT;
                end
            end
        end

        L_DONE: ;

        L_ERR: begin
            error <= 1'b1;
            done  <= 1'b0;
        end

        default: st <= L_ERR;
        endcase
    end
end

endmodule

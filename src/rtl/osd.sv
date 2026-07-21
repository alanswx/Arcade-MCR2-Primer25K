// On-screen game-select menu, drawn in the CORE video domain.
//
// The overlay is composited onto the core's RGB *before* the video path
// splits, so it appears identically on every output - the DDR3/HDMI
// framebuffer, analog VGA at 31 kHz, and native 15 kHz (the raster is only
// 240 lines there; the window geometry adapts). For the vertical games
// (Tron, Satan's Hollow - MAME ROT90) the text is drawn rotated so it reads
// correctly on a cabinet's rotated monitor.
//
// Controls (USB pad): Select+Start toggles the menu. Up/Down move, A loads
// the highlighted game from the SD pack (rom_loader restarts; the core sits
// in reset meanwhile, so the raster - and this menu - vanish for the ~1 s of
// loading and the new game boots). B exits. While the menu is open the top
// masks all game inputs.
//
// game_id is the game the core is RUNNING (drives the input/DIP mux in the
// top); it only changes after a load completes, so a failed SD load leaves
// the running game's controls intact.
//
// The '>' cursor marks the highlighted row, '*' the running game.
module osd #(
    parameter [2:0] GAME_DEFAULT = 3'd5   // pack slot order: 0 shollow,
                                          // 1 tron, 2 wacko, 3 kroozr,
                                          // 4 twotiger, 5 domino
)(
    input             clk,          // clk_sys (40 MHz)
    input             rst,

    // Core raster position (pre-capture-delay; the menu box lands a few px
    // from dead centre, which does not matter)
    input             pixel_tick,   // one strobe per 20 MHz core pixel
    input      [9:0]  hcnt,
    input             hblank,
    input             vblank,
    input             mode15,       // 240-line raster (15 kHz mode)

    input      [8:0]  rgb_in,       // {r,g,b} 3:3:3 from the core
    output     [8:0]  rgb_out,

    // Pad buttons, clk-synchronized, active high, UNMASKED
    input             btn_up,
    input             btn_down,
    input             btn_a,
    input             btn_b,
    input             btn_sel,
    input             btn_sta,

    // Game selection / loader handshake
    output reg [2:0]  game_id,        // game the core is running
    output reg [3:0]  load_slot,      // SD pack slot for rom_loader
    output reg        loader_restart, // 1-cycle pulse: reload load_slot
    input             loader_done,
    input             loader_error,
    input             sd_ready,       // card initialised

    output            osd_active
);

localparam [2:0] S_CLOSED = 3'd0,
                 S_OPEN   = 3'd1,
                 S_LOAD   = 3'd2,   // restart pulse issued, done not yet low
                 S_LOAD2  = 3'd3,   // loader running
                 S_ERR    = 3'd4;

reg [2:0] state = S_CLOSED;
reg [2:0] cursor = GAME_DEFAULT;

assign osd_active = (state != S_CLOSED);

// ---------------------------------------------------------------------------
// Menu FSM
// ---------------------------------------------------------------------------
reg up_r = 0, dn_r = 0, a_r = 0, b_r = 0, combo_r = 0;
wire combo = btn_sel & btn_sta;

always @(posedge clk) begin
    loader_restart <= 1'b0;
    up_r    <= btn_up;
    dn_r    <= btn_down;
    a_r     <= btn_a;
    b_r     <= btn_b;
    combo_r <= combo;

    if (rst) begin
        state     <= S_CLOSED;
        game_id   <= GAME_DEFAULT;
        cursor    <= GAME_DEFAULT;
        load_slot <= {1'b0, GAME_DEFAULT};
    end else begin
        case (state)

        S_CLOSED:
            if (combo & ~combo_r) begin
                state  <= S_OPEN;
                cursor <= game_id;
            end

        S_OPEN: begin
            if ((combo & ~combo_r) || (btn_b & ~b_r))
                state <= S_CLOSED;
            else if (btn_up & ~up_r)
                cursor <= (cursor == 3'd0) ? 3'd5 : cursor - 3'd1;
            else if (btn_down & ~dn_r)
                cursor <= (cursor == 3'd5) ? 3'd0 : cursor + 3'd1;
            else if (btn_a & ~a_r) begin
                load_slot      <= {1'b0, cursor};
                loader_restart <= 1'b1;
                state          <= S_LOAD;
            end
        end

        // The loader's done/error take a couple of cycles to drop after the
        // restart pulse; wait for that before watching for completion, or a
        // stale done would "finish" the load instantly.
        S_LOAD:
            if (!loader_done && !loader_error)
                state <= S_LOAD2;

        S_LOAD2:
            if (loader_done) begin
                game_id <= cursor;      // ROMs and input map switch together
                state   <= S_CLOSED;
            end else if (loader_error)
                state <= S_ERR;

        S_ERR:
            if ((btn_a & ~a_r) || (btn_b & ~b_r) || (combo & ~combo_r))
                state <= S_OPEN;

        default:
            state <= S_CLOSED;
        endcase
    end
end

// ---------------------------------------------------------------------------
// Raster position: x = hcnt, y = active lines since vblank
// ---------------------------------------------------------------------------
reg [9:0] ycnt = 0;
reg       hb_r = 0;
always @(posedge clk) begin
    if (pixel_tick) begin
        hb_r <= hblank;
        if (vblank) begin
            ycnt <= 10'd0;
            hb_r <= 1'b0;
        end else if (hblank & ~hb_r)
            ycnt <= ycnt + 10'd1;
    end
end

// Window geometry. Text plane is 24 cols x 14 rows of 8x8 = 192 x 112 px.
// ROT0 draws it as-is; ROT90 (Tron/Satan's Hollow) swaps the raster extents
// and remaps so the text reads upright on the cabinet's rotated monitor.
// x positions include the nominal 13 px capture offset of the visible area.
wire rot = (game_id == 3'd0) || (game_id == 3'd1);   // shollow, tron

wire [9:0] win_w = rot ? 10'd112 : 10'd192;
wire [9:0] win_h = rot ? 10'd192 : 10'd112;
wire [9:0] x0    = rot ? 10'd213 : 10'd173;
wire [9:0] y0    = rot ? (mode15 ? 10'd24 : 10'd144)
                       : (mode15 ? 10'd64 : 10'd184);

wire [9:0] xr = hcnt - x0;
wire [9:0] yr = ycnt - y0;
wire inwin = ~vblank && (hcnt >= x0) && (xr < win_w)
                     && (ycnt >= y0) && (yr < win_h);

// Text-plane coordinates: u = 0..191 across, v = 0..111 down.
// ROT90 mapping is "rotate clockwise to view" (MAME ROT90); if text comes
// out mirrored on real Tron hardware, swap to u=yr / v=111-xr (= ROT270).
wire [7:0] u = rot ? (8'd191 - yr[7:0]) : xr[7:0];
wire [6:0] v = rot ? xr[6:0] : yr[6:0];

// ---------------------------------------------------------------------------
// Menu text
// ---------------------------------------------------------------------------
// Every row is EXACTLY 24 characters (checked by tools/make_osd_font.py's
// sibling check in the build notes); shorter literals would left-pad with
// NULs and shift the text right.
localparam [191:0] TXT_TITLE   = "    MCR2 GAME SELECT    ";
localparam [191:0] TXT_G0      = "   SATANS HOLLOW        ";
localparam [191:0] TXT_G1      = "   TRON                 ";
localparam [191:0] TXT_G2      = "   WACKO                ";
localparam [191:0] TXT_G3      = "   KOZMIK KROOZR        ";
localparam [191:0] TXT_G4      = "   TWO TIGERS           ";
localparam [191:0] TXT_G5      = "   DOMINO MAN           ";
localparam [191:0] TXT_HELP    = "  A:LOAD  B:EXIT        ";
localparam [191:0] TXT_SDOK    = "  SD CARD: READY        ";
localparam [191:0] TXT_NOSD    = "  SD CARD: NOT FOUND    ";
localparam [191:0] TXT_LOADING = "  LOADING...            ";
localparam [191:0] TXT_FAILED  = "  LOAD FAILED           ";

function [7:0] row_char(input [191:0] rowtext, input [4:0] col);
    // char 0 sits in the MSBs
    row_char = rowtext[{5'd23 - col, 3'b000} +: 8];
endfunction

// ---------------------------------------------------------------------------
// Render pipeline: 2 pixel stages (cell/char lookup -> font fetch); the
// whole menu box just lands 2 px right of nominal, which is invisible.
// ---------------------------------------------------------------------------
reg        p1_in = 0;
reg [4:0]  p1_col;
reg [3:0]  p1_row;
reg [2:0]  p1_ub, p1_vb;
always @(posedge clk) begin
    if (pixel_tick) begin
        p1_in  <= inwin;
        p1_col <= u[7:3];
        p1_row <= v[6:3];
        p1_ub  <= u[2:0];
        p1_vb  <= v[2:0];
    end
end

reg [7:0] ch;
always @(*) begin
    ch = 8'h20;   // space
    case (p1_row)
        4'd0:  ch = row_char(TXT_TITLE, p1_col);
        4'd3:  ch = row_char(TXT_G0, p1_col);
        4'd4:  ch = row_char(TXT_G1, p1_col);
        4'd5:  ch = row_char(TXT_G2, p1_col);
        4'd6:  ch = row_char(TXT_G3, p1_col);
        4'd7:  ch = row_char(TXT_G4, p1_col);
        4'd8:  ch = row_char(TXT_G5, p1_col);
        4'd10: ch = row_char(TXT_HELP, p1_col);
        4'd12: begin
            case (state)
                S_LOAD, S_LOAD2: ch = row_char(TXT_LOADING, p1_col);
                S_ERR:           ch = row_char(TXT_FAILED, p1_col);
                default:         ch = row_char(sd_ready ? TXT_SDOK : TXT_NOSD,
                                               p1_col);
            endcase
        end
        default: ;
    endcase
    // game rows: '>' = cursor, '*' = running game
    if (p1_row >= 4'd3 && p1_row <= 4'd8) begin
        if (p1_col == 5'd1  && (p1_row - 4'd3) == {1'b0, cursor})
            ch = ">";
        if (p1_col == 5'd17 && (p1_row - 4'd3) == {1'b0, game_id})
            ch = "*";
    end
end

// ASCII 0x20..0x5F -> font index 0..63
wire [5:0] glyph = {ch[6], ch[4:0]};

reg [7:0] font_rom [0:511];
initial $readmemh("osd_font.hex", font_rom);

reg [7:0] p2_byte;
reg [2:0] p2_ub;
reg       p2_in = 0;
always @(posedge clk) begin
    if (pixel_tick) begin
        p2_byte <= font_rom[{glyph, p1_vb}];
        p2_ub   <= p1_ub;
        p2_in   <= p1_in;
    end
end

wire pix = p2_byte[3'd7 - p2_ub];   // bit 7 = leftmost pixel

// white text on a dark blue box; game video passes through untouched
// everywhere else (and entirely, when the menu is closed)
assign rgb_out = (osd_active && p2_in) ? (pix ? 9'b111_111_111
                                              : 9'b000_000_010)
                                       : rgb_in;

endmodule

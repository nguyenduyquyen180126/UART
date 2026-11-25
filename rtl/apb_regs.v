`timescale 1ns/1ps
module apb_regs(
    // SYSTEM SIGNAL
    input pclk,
    input presetn,

    // APB INTERFACES
    input psel,
    input penable,
    input pwrite,
    input [11:0] paddr,
    /* verilator lint_off UNUSEDSIGNAL */
    input [3:0] pstrb,   // Upper byte strobes [3:2] are RFU.
    input [31:0] pwdata, // Upper APB write-data bits are reserved and ignored.
    /* verilator lint_on UNUSEDSIGNAL */
    output pready,
    output pslverr,
    output [31:0] prdata,

    // TX RX CFG OUTPUT
    output [1:0] data_bits,
    output stop_bits,
    output parity_en,
    output parity_type,
    output tx_dis,
    output rx_dis,

    // CONTROL OUTPUT
    output start_tx,
    output soft_rst,

    output [7:0] tx_data,

    input [7:0] rx_data,

    // STATUS INPUT
    input tx_done,
    input rx_done,
    input parity_err,
    input rx_busy,
    input frame_err,
    input rx_overrun,

    // BAUD OUTPUT
    output [11:0] div_int,
    output [15:12] div_frac,

    output irq
);
    localparam [2:0] IDX_TXDATA = 3'b000; // 0x000
    localparam [2:0] IDX_RXDATA = 3'b001; // 0x004
    localparam [2:0] IDX_CFG    = 3'b010; // 0x008
    localparam [2:0] IDX_CTRL   = 3'b011; // 0x00C
    localparam [2:0] IDX_STAT   = 3'b100; // 0x010
    localparam [2:0] IDX_BAUD   = 3'b101; // 0x014
    localparam [2:0] IDX_IER    = 3'b110; // 0x018

    // REGS (36 FFs total — exact architectural state required by za.html)
    reg [7:0]  tx_data_reg;
    reg [6:0]  cfg;          // rx_dis, tx_dis, parity_type, parity_en, stop_bits, data_bits[1:0]
    reg        start_reg;
    reg        soft_rst_reg;
    reg [15:0] baud;         // div_frac[15:12], div_int[11:0]
    reg [2:0]  ier;          // err_ie, rx_done_ie, tx_done_ie

    // STAT WIRE: overrun, frame_err, rx_dis, tx_dis, rx_busy, parity_err, rx_done, tx_done
    wire [7:0] stat = {rx_overrun, frame_err, cfg[6], cfg[5], rx_busy, parity_err, rx_done, tx_done};

    // OUTPUT ASSIGNMENTS
    assign data_bits   = cfg[1:0];
    assign stop_bits   = cfg[2];
    assign parity_en   = cfg[3];
    assign parity_type = cfg[4];
    assign tx_dis      = cfg[5];
    assign rx_dis      = cfg[6];

    assign start_tx    = start_reg;
    assign soft_rst    = soft_rst_reg;
    assign tx_data     = tx_data_reg;
    assign div_int     = baud[11:0];
    assign div_frac    = baud[15:12];
    assign pready      = 1'b1;

    assign irq = (ier[0] & tx_done) |
                 (ier[1] & rx_done) |
                 (ier[2] & (parity_err | frame_err | rx_overrun));

    // V2 PPA: Single shared 12-bit address validator + 3-bit index.
    wire       apb_access    = psel & penable;
    wire       apb_rd        = apb_access & ~pwrite;
    wire       apb_wr        = apb_access &  pwrite;
    wire [2:0] reg_idx       = paddr[4:2];
    wire       addr_valid    = ~(|paddr[11:5] | |paddr[1:0] | (&reg_idx));

    wire       busy          = (~tx_done) | rx_busy;
    wire       strb_01       = pstrb[0] | pstrb[1];
    wire       ctrl_soft_rst = pstrb[1] & pwdata[8];
    wire       ctrl_start_tx = pstrb[0] & pwdata[0];

    wire       baud_lo_zero  = ~|(pstrb[0] ? pwdata[7:0]  : baud[7:0]);
    wire       baud_hi_zero  = ~|(pstrb[1] ? pwdata[11:8] : baud[11:8]);
    wire       baud_zero     = baud_lo_zero & baud_hi_zero;

    // Split read mux: 8-bit mux for byte 0 + single AND-gate for BAUD byte 1.
    reg [7:0] prdata_b0;
    always @(*) begin
        case (reg_idx)
            IDX_TXDATA: prdata_b0 = tx_data_reg;
            IDX_RXDATA: prdata_b0 = rx_data;
            IDX_CFG:    prdata_b0 = {1'b0, cfg};
            IDX_STAT:   prdata_b0 = stat;
            IDX_BAUD:   prdata_b0 = baud[7:0];
            IDX_IER:    prdata_b0 = {5'b0, ier};
            default:    prdata_b0 = 8'h00; // CTRL (3'b011) and invalid (3'b111)
        endcase
    end

    wire rd_ok   = apb_rd & addr_valid;
    wire rd_baud = rd_ok & (reg_idx == IDX_BAUD);
    assign prdata = {16'h0000, rd_baud ? baud[15:8] : 8'h00, rd_ok ? prdata_b0 : 8'h00};

    // Per-register write protection / error check (E2, E3, E4, E5, E6)
    reg wr_reg_err;
    always @(*) begin
        case (reg_idx)
            IDX_TXDATA: wr_reg_err = (~tx_done) & pstrb[0];
            IDX_RXDATA: wr_reg_err = 1'b1;
            IDX_CFG:    wr_reg_err = busy & pstrb[0];
            IDX_CTRL:   wr_reg_err = (~ctrl_soft_rst) & (~tx_done) & ctrl_start_tx;
            IDX_STAT:   wr_reg_err = 1'b1;
            IDX_BAUD:   wr_reg_err = strb_01 & (busy | baud_zero);
            IDX_IER:    wr_reg_err = 1'b0;
            default:    wr_reg_err = 1'b1;
        endcase
    end

    assign pslverr = apb_access & (~addr_valid | (pwrite & wr_reg_err));

    // V2 Timing/Area optimization: decouple per-register write enables from
    // the shared wr_reg_err mux so baud_zero/busy never lengthen TXDATA/CFG/IER
    // write paths (cuts pre-layout SS R2R arrival from 6.305 ns to 4.540 ns).
    wire apb_wr_ok   = apb_wr & addr_valid;
    wire do_soft_rst = apb_wr_ok & (reg_idx == IDX_CTRL)   & ctrl_soft_rst;
    wire wr_txdata   = apb_wr_ok & (reg_idx == IDX_TXDATA) & tx_done & pstrb[0];
    wire wr_cfg      = apb_wr_ok & (reg_idx == IDX_CFG)    & (~busy) & pstrb[0];
    wire wr_start    = apb_wr_ok & (reg_idx == IDX_CTRL)   & (~ctrl_soft_rst) & tx_done & ctrl_start_tx;
    wire wr_baud_ok  = apb_wr_ok & (reg_idx == IDX_BAUD)   & (~busy) & (~baud_zero);
    wire wr_ier      = apb_wr_ok & (reg_idx == IDX_IER)    & pstrb[0];

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            tx_data_reg  <= 8'h00;
            cfg          <= 7'h00;
            baud         <= 16'h900D;
            ier          <= 3'h0;
            start_reg    <= 1'b0;
            soft_rst_reg <= 1'b0;
        end else begin
            soft_rst_reg <= do_soft_rst;
            start_reg    <= wr_start;

            if (do_soft_rst) begin
                tx_data_reg <= 8'h00;
                cfg         <= 7'h00;
                baud        <= 16'h900D;
                ier         <= 3'h0;
            end else begin
                if (wr_txdata) tx_data_reg <= pwdata[7:0];
                if (wr_cfg)    cfg         <= pwdata[6:0];
                if (wr_baud_ok) begin
                    if (pstrb[0]) baud[7:0]  <= pwdata[7:0];
                    if (pstrb[1]) baud[15:8] <= pwdata[15:8];
                end
                if (wr_ier)    ier         <= pwdata[2:0];
            end
        end
    end

endmodule

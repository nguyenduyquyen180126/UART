`timescale 1ns/1ps

// =============================================================================
// Module Name: avalon2apb
// Description: Bridge Avalon Memory-Mapped (Avalon-MM) Slave to APB Master.
//              Used as a frontend bridge before apb_slave to allow Nios V
//              (or any Avalon-MM Host) to communicate with APB peripherals.
// =============================================================================

module avalon2apb #(
    parameter ADDR_WIDTH     = 12, // Address width (default matches apb_slave: 12-bit)
    parameter DATA_WIDTH     = 32, // Data width (default: 32-bit)
    parameter USE_CHIPSELECT = 0,  // 0: Ignore chipselect (auto-detect by read/write), 1: Use avl_chipselect
    parameter ADDR_MODE      = 0   // 0: Byte addressing (paddr = avl_address)
                                   // 1: Word addressing (paddr = {avl_address[ADDR_WIDTH-3:0], 2'b00})
)(
    // -------------------------------------------------------------------------
    // Clock & Reset (Synchronous with Avalon-MM & APB domains)
    // -------------------------------------------------------------------------
    input  wire                    clk,
    input  wire                    reset_n,

    // -------------------------------------------------------------------------
    // Avalon-MM Slave Interface (Connecting to Nios V / Platform Designer)
    // -------------------------------------------------------------------------
    input  wire                    avl_chipselect,
    input  wire                    avl_read,
    input  wire                    avl_write,
    input  wire [ADDR_WIDTH-1:0]   avl_address,
    input  wire [DATA_WIDTH-1:0]   avl_writedata,
    input  wire [(DATA_WIDTH/8)-1:0] avl_byteenable,
    output wire [DATA_WIDTH-1:0]   avl_readdata,
    output wire                    avl_waitrequest,
    output wire [1:0]              avl_response,    // 2'b00: OKAY, 2'b10: SLVERR

    // -------------------------------------------------------------------------
    // APB Master Interface (Connecting to apb_slave)
    // -------------------------------------------------------------------------
    output wire                    pclk,
    output wire                    preset_n,
    output reg                     psel,
    output reg                     penable,
    output reg                     pwrite,
    output reg  [ADDR_WIDTH-1:0]   paddr,
    output reg  [DATA_WIDTH-1:0]   pwdata,
    input  wire                    pready,
    input  wire                    pslverr,
    input  wire [DATA_WIDTH-1:0]   prdata
);

    // -------------------------------------------------------------------------
    // Pass-through Clock & Reset to APB bus
    // -------------------------------------------------------------------------
    assign pclk     = clk;
    assign preset_n = reset_n;

    // -------------------------------------------------------------------------
    // Address Decoding according to ADDR_MODE
    // -------------------------------------------------------------------------
    wire [ADDR_WIDTH-1:0] internal_addr;
    generate
        if (ADDR_MODE == 1) begin : gen_word_addr
            assign internal_addr = {avl_address[ADDR_WIDTH-3:0], 2'b00};
        end else begin : gen_byte_addr
            assign internal_addr = avl_address;
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Avalon Request Qualification
    // -------------------------------------------------------------------------
    wire cs = (USE_CHIPSELECT == 1) ? avl_chipselect : 1'b1;
    wire req_valid = cs & (avl_read | avl_write);

    // -------------------------------------------------------------------------
    // Bridge FSM States
    // -------------------------------------------------------------------------
    localparam [1:0] ST_IDLE       = 2'b00; // Idle state, waits for Avalon read/write
    localparam [1:0] ST_SETUP      = 2'b01; // APB Setup phase (psel=1, penable=0)
    localparam [1:0] ST_ACCESS     = 2'b10; // APB Access phase (apb_slave is in ACCESS, data transferred)

    reg [1:0] state, next_state;

    // Registers to preserve response and read data after completion
    reg [DATA_WIDTH-1:0] readdata_reg;
    reg [1:0]            response_reg;

    // -------------------------------------------------------------------------
    // FSM State Register
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= ST_IDLE;
        end else begin
            state <= next_state;
        end
    end

    // -------------------------------------------------------------------------
    // Next-State Logic
    // -------------------------------------------------------------------------
    always @(*) begin
        next_state = state;
        case (state)
            ST_IDLE: begin
                if (req_valid)
                    next_state = ST_SETUP;
            end

            ST_SETUP: begin
                next_state = ST_ACCESS;
            end

            ST_ACCESS: begin
                if (pready)
                    next_state = ST_IDLE;
            end

            default: next_state = ST_IDLE;
        endcase
    end

    // -------------------------------------------------------------------------
    // APB Signal Generation & Output Registers
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            psel         <= 1'b0;
            penable      <= 1'b0;
            pwrite       <= 1'b0;
            paddr        <= {ADDR_WIDTH{1'b0}};
            pwdata       <= {DATA_WIDTH{1'b0}};
            readdata_reg <= {DATA_WIDTH{1'b0}};
            response_reg <= 2'b00;
        end else begin
            case (state)
                ST_IDLE: begin
                    if (req_valid) begin
                        psel    <= 1'b1;
                        penable <= 1'b0;
                        pwrite  <= avl_write;
                        paddr   <= internal_addr;
                        pwdata  <= avl_writedata;
                    end else begin
                        psel    <= 1'b0;
                        penable <= 1'b0;
                        pwrite  <= 1'b0;
                    end
                end

                ST_SETUP: begin
                    psel    <= 1'b1;
                    penable <= 1'b1; // Assert penable for access phase
                end

                ST_ACCESS: begin
                    if (pready) begin
                        psel         <= 1'b0;
                        penable      <= 1'b0;
                        pwrite       <= 1'b0;
                        readdata_reg <= prdata;
                        response_reg <= (pslverr) ? 2'b10 : 2'b00;
                    end else begin
                        psel    <= 1'b1;
                        penable <= 1'b1;
                    end
                end

                default: begin
                    psel    <= 1'b0;
                    penable <= 1'b0;
                end
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Avalon-MM Output Signals
    // -------------------------------------------------------------------------
    // Read data and slave response: during ACCESS, driven directly from APB;
    // in other states, retained by registers.
    assign avl_readdata = (state == ST_ACCESS) ? prdata : readdata_reg;
    assign avl_response = (state == ST_ACCESS) ? ((pslverr) ? 2'b10 : 2'b00) : response_reg;

    // waitrequest: Asserted whenever bridge is busy or a new transaction begins,
    // deasserted only when APB slave signals pready in the ST_ACCESS state.
    reg waitrequest_comb;
    always @(*) begin
        case (state)
            ST_IDLE:   waitrequest_comb = req_valid;
            ST_SETUP:  waitrequest_comb = 1'b1;
            ST_ACCESS: waitrequest_comb = !pready;
            default:   waitrequest_comb = 1'b1;
        endcase
    end

    assign avl_waitrequest = waitrequest_comb;

endmodule

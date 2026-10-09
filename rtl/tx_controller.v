module tx_controller(
    input clk, rst_n,
    input start_tx,
    input parity_en,
    input stop_last,
    input tick_last,
    input bit_last,
    output reg tx_done,
    output reg [1:0]tx_sel,
    output reg load_reg,
    output reg shift_reg,
    output reg clr_bit,
    output reg clr_stop
);
    localparam IDLE     = 3'b000;
    localparam START    = 3'b001;
    localparam DATA     = 3'b011;
    localparam PARITY   = 3'b010;
    localparam STOP     = 3'b110;

    reg [2:0] state;
    reg [2:0] next_state;

    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case(state)
            IDLE: begin
                if(start_tx && tick_last) begin
                    next_state = START;
                end
            end
            START: begin
                if(tick_last) begin
                    next_state = DATA;
                end
            end
            DATA: begin
                if(~bit_last && tick_last) begin
                    next_state = DATA;
                end
                else if(bit_last && tick_last && parity_en) begin
                    next_state = PARITY;
                end
                else if(bit_last && tick_last && ~parity_en) begin
                    next_state = STOP;
                end
            end
            PARITY: begin
                if(tick_last) begin
                    next_state = STOP;
                end
            end
            STOP: begin
                if(~stop_last && tick_last) begin
                    next_state = STOP;
                end                
                else if(stop_last && tick_last) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    always @(*) begin
        tx_done     = 1'b0;
        tx_sel      = 1'b0;
        clr_bit     = 1'b0;
        clr_stop    = 1'b0;
        load_reg    = 1'b0;
        shift_reg   = 1'b0;

        case(state)
            IDLE: begin
                tx_done = 1'b0;
                tx_sel = 2'b01;
                clr_bit = 1'b1;
                clr_stop = 1'b1;
                if(start_tx && tick_last) begin
                    load_reg = 1'b1;
                end
            end
            START: begin
                tx_done = 1'b0;
                tx_sel = 2'b00;
                clr_bit = 1'b1;
                clr_stop = 1'b1;
            end
            DATA: begin
                tx_done = 1'b0;
                tx_sel = 2'b10;
                clr_bit = 1'b0;
                clr_stop = 1'b1;
                if(~bit_last && tick_last) begin
                    shift_reg = 1'b1;
                end
                else if(bit_last && tick_last && parity_en) begin
                    
                end
                else if(bit_last && tick_last && ~parity_en) begin
                    
                end
            end
            PARITY: begin
                tx_done = 1'b0;
                tx_sel = 2'b11;
                clr_bit = 1'b1;
                clr_stop = 1'b1;
                if(tick_last) begin 
                    
                end
            end
            STOP: begin
                tx_done = 1'b0;
                tx_sel = 2'b01;
                clr_bit = 1'b1;
                clr_stop = 1'b0;
                if(~stop_last && tick_last) begin
                    
                end
                else if(stop_last && tick_last) begin
                    tx_done = 1'b1; // Mealy output: 1 clock pulse on transition to IDLE
                end
            end
        endcase
    end
endmodule
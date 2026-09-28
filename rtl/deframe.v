module deframe(
        input clk,
        input rst_n,
        input bit_last,
        input parity_en,
        input [11:0] data_in,
        input [3:0]  num_data_b,
        input [1:0]  num_stop_b,
        output reg [31:0] rx_data,
        output reg parity_exp,
        output reg        parity_bit
    );
    
        always @(posedge clk or negedge rst_n) begin
            if (~rst_n) begin
                rx_data    <= 32'd0;
                parity_bit <= 1'b0;
            end
            else if (bit_last) begin
                case(num_data_b)
                    4'd5: begin
                        if (parity_en) begin
                            rx_data    <= {27'b0, data_in[10:6]};
                            parity_exp <= ^data_in[10:6];
                            parity_bit <= data_in[11];
                        end else begin
                            rx_data    <= {27'b0, data_in[11:7]};
                            parity_bit <= 1'b0;
                        end
                    end
    
                    4'd6: begin
                        if (parity_en) begin
                            rx_data    <= {26'b0, data_in[10:5]};
                            parity_exp <= ^data_in[10:5];
                            parity_bit <= data_in[11];
                        end else begin
                            rx_data    <= {26'b0, data_in[11:6]};
                            parity_bit <= 1'b0;
                        end
                    end
    
                    4'd7: begin
                        if (parity_en) begin
                            rx_data    <= {25'b0, data_in[10:4]};
                            parity_exp <= ^data_in[10:4];
                            parity_bit <= data_in[11];
                        end else begin
                            rx_data    <= {25'b0, data_in[11:5]};
                            parity_bit <= 1'b0;
                        end
                    end
    
                    4'd8: begin
                        if (parity_en) begin
                            rx_data    <= {24'b0, data_in[10:3]};
                            parity_exp <= ^data_in[10:3];
                            parity_bit <= data_in[11];
                        end else begin
                            rx_data    <= {24'b0, data_in[11:4]};
                            parity_bit <= 1'b0;
                        end
                    end
                endcase
            end
        end
    
    endmodule
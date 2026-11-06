// Top-level Verilog for NIOS V SoC on Terasic DE2-115
module NIOS (
    input  wire        CLOCK_50,  // Xung clock 50MHz từ bộ dao động trên board (PIN_Y2)
    input  wire [1:0]  KEY,       // KEY[0] làm Reset (PIN_M23), KEY[1] làm nút gửi UART từ SW (PIN_M21)
    input  wire [7:0]  SW,        // 8 công tắc gạt SW[7:0] để nạp dữ liệu/ký tự lên PC (PIN_AB28..PIN_AB26)

    output wire [7:0]  LEDG,      // 8 đèn LED xanh lá cây (PIN_E21..PIN_G21)
    output wire [6:0]  HEX0,      // LED 7 thanh hàng đơn vị (PIN_G18..PIN_H22)
    output wire [6:0]  HEX2,
    output wire [6:0]  HEX3,
    output wire [6:0]  HEX1,      // LED 7 thanh hàng chục (PIN_M24..PIN_U24)

    // 2 Chân giao tiếp UART với module USB-to-UART ngoài qua Header JP5
    input  wire        UART_RXD,  // Nhận dữ liệu từ TX của module USB2UART (PIN_AB22)
    output wire        UART_TXD   // Gửi dữ liệu sang RX của module USB2UART (PIN_AC15)
);

    wire [7:0] pio_display;
    wire [7:0] pio_counter;

    // Khởi tạo hệ thống vi xử lý Nios V/m SoC từ Platform Designer
    system u0 (
        .pio_hex_external_connection_export (pio_counter),
        .clk_clk                            (CLOCK_50),                  // clk.clk
        .reset_reset_n                      (KEY[0]),                    // reset.reset_n (tích cực mức thấp)
        .pio_0_external_connection_export   (pio_display),               // pio_0: hiển thị ra LED & HEX
        .pio_sw_external_connection_export  (SW),                        // pio_sw: đọc 8 công tắc SW[7:0]
        .pio_key_external_connection_export (KEY[1]),                    // pio_key: đọc nút nhấn KEY[1]
        .uart_external_uart_rx              (UART_RXD),                  // UART nhận
        .uart_external_uart_tx              (UART_TXD)                   // UART phát
    );

    // Giải mã hiển thị LED 7 đoạn (HEX0 và HEX1) - Tích cực mức thấp (Active Low)
    seven_segment_decoder u_hex0 (
        .hex_digit (pio_display[3:0]), // 4-bit thấp (hàng đơn vị)
        .seg       (HEX0)
    );

    seven_segment_decoder u_hex1 (
        .hex_digit (pio_display[7:4]), // 4-bit cao (hàng chục)
        .seg       (HEX1)
    );

    // Đồng thời xuất ra 8 LED xanh để tiện quan sát nhị phân
    seven_segment_decoder u_hex2 (.hex_digit(pio_counter[3:0]), .seg(HEX2));
    seven_segment_decoder u_hex3 (.hex_digit(pio_counter[7:4]), .seg(HEX3));
    assign LEDG = pio_display;

endmodule

// Module giải mã số Hex 4-bit ra 7 đoạn (Common Anode trên kit DE2-115: bit 0 = sáng, bit 1 = tắt)
module seven_segment_decoder (
    input  wire [3:0] hex_digit,
    output reg  [6:0] seg
);
    always @(*) begin
        case (hex_digit)
            4'h0: seg = 7'b100_0000; // 0
            4'h1: seg = 7'b111_1001; // 1
            4'h2: seg = 7'b010_0100; // 2
            4'h3: seg = 7'b011_0000; // 3
            4'h4: seg = 7'b001_1001; // 4
            4'h5: seg = 7'b001_0010; // 5
            4'h6: seg = 7'b000_0010; // 6
            4'h7: seg = 7'b111_1000; // 7
            4'h8: seg = 7'b000_0000; // 8
            4'h9: seg = 7'b001_0000; // 9
            4'hA: seg = 7'b000_1000; // A
            4'hB: seg = 7'b000_0011; // b
            4'hC: seg = 7'b100_0110; // C
            4'hD: seg = 7'b010_0001; // d
            4'hE: seg = 7'b000_0110; // E
            4'hF: seg = 7'b000_1110; // F
            default: seg = 7'b111_1111; // Tắt hết
        endcase
    end
endmodule
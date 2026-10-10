dra#include <stdint.h>
#include "system.h"
#include "io.h"
#include "altera_avalon_pio_regs.h"

// Base addresses (Khớp với cấu hình Platform Designer / Qsys)
#ifndef APB_UART_0_BASE
#define APB_UART_0_BASE 0x00020000
#endif

#ifndef PIO_0_BASE
#define PIO_0_BASE   0x00010000 // 2 LED 7 đoạn HEX1 (cao) và HEX0 (thấp)
#endif

#ifndef PIO_SW_BASE
#define PIO_SW_BASE  0x00010020 // 8 công tắc gạt SW[7:0]
#endif

#ifndef PIO_KEY_BASE
#define PIO_KEY_BASE 0x00010030 // Nút nhấn KEY[1]
#endif

// Offset các thanh ghi APB UART (Khớp với rtl/reg_uart.v)
#define UART_TX_DATA_REG  (APB_UART_0_BASE + 0x00) // Thanh ghi ghi dữ liệu phát
#define UART_RX_DATA_REG  (APB_UART_0_BASE + 0x04) // Thanh ghi đọc dữ liệu nhận
#define UART_CFG_REG      (APB_UART_0_BASE + 0x08) // Cấu hình baudrate và khung truyền
#define UART_CTRL_REG     (APB_UART_0_BASE + 0x0C) // Thanh ghi điều khiển (start_tx)
#define UART_STT_REG      (APB_UART_0_BASE + 0x10) // Thanh ghi trạng thái (tx_done, rx_done, error)

// Hàm trễ mili-giây
void delay_ms(int ms) {
    for (volatile int i = 0; i < ms * 4000; i++) {
        __asm__ volatile ("nop");
    }
}

// Khởi tạo UART: Baud 9600, 8 data bits, 1 stop bit, no parity
// Ghi vào UART_CFG_REG (0x08): (0x2 << 5) | 0x3 = 0b0100_0011 (0x43)
void uart_init(void) {
    IOWR_32DIRECT(UART_CFG_REG, 0, (0x2 << 5) | 0x3);
}

// Gửi 1 ký tự ra UART lên máy tính (kèm timeout chống treo)
int uart_putc(char c) {
    uint32_t timeout = 500000;
    // Đợi cờ tx_done (bit 0 của UART_STT_REG) lên 1 (TX rảnh)
    while (((IORD_32DIRECT(UART_STT_REG, 0) & 0x01) == 0) && --timeout);
    if (timeout == 0) return -1; // Quá thời gian chờ

    // Ghi byte ký tự vào bộ đệm TX
    IOWR_32DIRECT(UART_TX_DATA_REG, 0, (uint32_t)c);
    // Kích xung start_tx = 1 (Hardware tự động xóa về 0 sau 1 chu kỳ clock)
    IOWR_32DIRECT(UART_CTRL_REG, 0, 0x01);
    return 0;
}

// Kiểm tra xem UART có byte nhận từ PC không (cờ rx_done = bit 1 của UART_STT_REG)
int uart_has_data(void) {
    return (IORD_32DIRECT(UART_STT_REG, 0) & 0x02) ? 1 : 0;
}

// Đọc 1 ký tự từ UART
char uart_getc(void) {
    while (!uart_has_data());
    // Đọc byte dữ liệu từ UART_RX_DATA_REG (Đồng thời phần cứng tự xóa cờ rx_done)
    return (char)(IORD_32DIRECT(UART_RX_DATA_REG, 0) & 0xFF);
}

// Gửi 1 chuỗi ký tự qua UART
void uart_puts(const char *s) {
    while (*s) {
        uart_putc(*s++);
    }
}

int main(void) {
    // 1. Khởi tạo UART 9600 baud
    uart_init();

    // 2. Hiển thị 00 lên 2 LED 7 đoạn HEX1-HEX0 lúc khởi động
    IOWR_ALTERA_AVALON_PIO_DATA(PIO_0_BASE, 0x00);

    // 3. Gửi lời chào lên terminal máy tính
    uart_puts("\r\n=== DE2-115 UART READY ===\r\n");

    uint8_t prev_key1 = 1;

    while (1) {
        // -------------------------------------------------------------
        // [A] CHẾ ĐỘ LOOPBACK TỰ ĐỘNG:
        // PC gửi ký tự xuống RX -> Core đọc RX -> Echo lại TX về PC
        // Đồng thời xuất mã Hex ASCII ra 2 LED 7 đoạn HEX1-HEX0
        // -------------------------------------------------------------
        if (uart_has_data()) {
            char ch = uart_getc();

            // 1. Phản hồi ký tự về PC ngay lập tức
            uart_putc(ch);

            // 2. Hiển thị mã ASCII (dưới dạng số Hex) lên 2 LED 7 đoạn
            // Ví dụ: Gõ 'A' (0x41) -> HEX1 hiện 4, HEX0 hiện 1
            IOWR_ALTERA_AVALON_PIO_DATA(PIO_0_BASE, (uint8_t)ch);
        }

        // -------------------------------------------------------------
        // [B] TÍNH NĂNG GỬI DỮ LIỆU BẰNG CÔNG TẮC GẠT SW + NÚT NHẤN KEY[1]:
        // -------------------------------------------------------------
        // Đọc trạng thái nút KEY[1] (Tích cực mức thấp: nhả = 1, nhấn = 0)
        uint8_t key1 = (uint8_t)(IORD_ALTERA_AVALON_PIO_DATA(PIO_KEY_BASE) & 0x01);
        if (prev_key1 == 1 && key1 == 0) { // Bắt sườn xuống khi vừa nhấn nút
            // Đọc 8 công tắc gạt SW[7:0]
            uint8_t sw_val = (uint8_t)(IORD_ALTERA_AVALON_PIO_DATA(PIO_SW_BASE) & 0xFF);

            // Gửi byte giá trị SW lên máy tính qua UART TX
            uart_putc((char)sw_val);

            // Hiển thị giá trị SW lên 2 LED 7 đoạn HEX1-HEX0
            IOWR_ALTERA_AVALON_PIO_DATA(PIO_0_BASE, sw_val);

            delay_ms(50); // Chống dội phím (debounce)
        }
        prev_key1 = key1;
    }

    return 0;
}

#include <stdint.h>
#include <stdbool.h>
#include "system.h"
#include "io.h"
#include "altera_avalon_pio_regs.h"

#ifdef APB_UART_0_IRQ
#include "sys/alt_irq.h"
#endif

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

// Offset các thanh ghi APB UART (Khớp với rtl/uart_regs.v)
#define UART_TX_DATA_REG  (APB_UART_0_BASE + 0x00) // Thanh ghi ghi dữ liệu phát
#define UART_RX_DATA_REG  (APB_UART_0_BASE + 0x04) // Thanh ghi đọc dữ liệu nhận
#define UART_CFG_REG      (APB_UART_0_BASE + 0x08) // Cấu hình baudrate và khung truyền
#define UART_STT_REG      (APB_UART_0_BASE + 0x0C) // Thanh ghi trạng thái (tx_ready, rx_ready, error, overrun)
#define UART_IER_REG      (APB_UART_0_BASE + 0x10) // Thanh ghi cho phép ngắt (rx_ie, tx_ie, oe_ie)

// Mặt nạ bit thanh ghi STT
#define UART_STT_TX_READY (1 << 0) // Bit 0: Bộ phát sẵn sàng & TX FIFO rỗng (1)
#define UART_STT_TX_DONE  (1 << 0) // Alias tương thích ngược với code cũ
#define UART_STT_RX_DONE  (1 << 1) // Bit 1: Có byte mới trong bộ nhận (1)
#define UART_STT_ERROR    (1 << 2) // Bit 2: Lỗi Parity hoặc Frame
#define UART_STT_OVERRUN  (1 << 3) // Bit 3: Lỗi tràn dữ liệu Overrun

// Mặt nạ bit thanh ghi IER
#define UART_IER_RX_IE    (1 << 0) // Bit 0: Cho phép ngắt nhận RX
#define UART_IER_TX_IE    (1 << 1) // Bit 1: Cho phép ngắt phát TX
#define UART_IER_OE_IE    (1 << 2) // Bit 2: Cho phép ngắt lỗi Overrun

// =============================================================================
// CẤU TRÚC SOFTWARE RING BUFFER (BỘ ĐỆM VÒNG TRONG RAM CHỐNG TRÀN OVERRUN)
// =============================================================================
#define UART_RX_BUF_SIZE 256 // Bộ đệm 256 bytes hứng dữ liệu từ ngắt

typedef struct {
    volatile uint8_t  buf[UART_RX_BUF_SIZE];
    volatile uint16_t head;
    volatile uint16_t tail;
    volatile uint32_t overrun_count; // Đếm số lần bị tràn buffer
} uart_ring_buf_t;

static uart_ring_buf_t g_rx_ring = {0};

// Đẩy 1 ký tự vào bộ đệm vòng (gọi trong ISR ngắt phần cứng)
static inline void ringbuf_put(uint8_t c) {
    uint16_t next = (g_rx_ring.head + 1) % UART_RX_BUF_SIZE;
    if (next != g_rx_ring.tail) {
        g_rx_ring.buf[g_rx_ring.head] = c;
        g_rx_ring.head = next;
    } else {
        g_rx_ring.overrun_count++; // Buffer đầy, ghi nhận lỗi tràn phần mềm
    }
}

// Lấy 1 ký tự ra khỏi bộ đệm vòng (gọi trong luồng chính main)
static inline int ringbuf_get(uint8_t *c) {
    if (g_rx_ring.head == g_rx_ring.tail) {
        return 0; // Bộ đệm rỗng
    }
    *c = g_rx_ring.buf[g_rx_ring.tail];
    g_rx_ring.tail = (g_rx_ring.tail + 1) % UART_RX_BUF_SIZE;
    return 1;
}

// Kiểm tra số byte hiện có sẵn trong bộ đệm vòng
static inline int ringbuf_available(void) {
    return (g_rx_ring.head - g_rx_ring.tail + UART_RX_BUF_SIZE) % UART_RX_BUF_SIZE;
}

// =============================================================================
// HÀM PHỤC VỤ NGẮT PHẦN CỨNG (INTERRUPT SERVICE ROUTINE - ISR)
// =============================================================================
#ifdef APB_UART_0_IRQ
static void apb_uart_isr(void *context) {
    uint32_t stt = IORD_32DIRECT(UART_STT_REG, 0);

    // 1. Kiểm tra nếu có lỗi tràn phần cứng Overrun (byte mới đến khi byte cũ chưa đọc)
    if (stt & UART_STT_OVERRUN) {
        g_rx_ring.overrun_count++;
    }

    // 2. Kiểm tra nếu có dữ liệu RX mới đến
    if (stt & UART_STT_RX_DONE) {
        // Đọc byte dữ liệu từ UART_RX_DATA_REG
        // (Thao tác này tự động xóa cờ rx_done và hạ chân IRQ về 0 trong phần cứng)
        uint8_t ch = (uint8_t)(IORD_32DIRECT(UART_RX_DATA_REG, 0) & 0xFF);
        ringbuf_put(ch);
    }
}
#endif

// Hàm trễ mili-giây
void delay_ms(int ms) {
    for (volatile int i = 0; i < ms * 4000; i++) {
        __asm__ volatile ("nop");
    }
}

// Khởi tạo UART: Baud 9600, 8 data bits, 1 stop bit, no parity & Bật ngắt IRQ
void uart_init(void) {
    // 1. Cấu hình baudrate và khung truyền 8-N-1
    IOWR_32DIRECT(UART_CFG_REG, 0, (0x2 << 5) | 0x3);

    // 2. Đăng ký hàm ngắt ISR với bộ điều khiển ngắt của CPU Nios V
#ifdef APB_UART_0_IRQ
    alt_ic_isr_register(
        APB_UART_0_IRQ_INTERRUPT_CONTROLLER_ID,
        APB_UART_0_IRQ,
        apb_uart_isr,
        NULL,
        0x0
    );

    // 3. Bật ngắt nhận RX và ngắt Overrun trong thanh ghi IER phần cứng
    IOWR_32DIRECT(UART_IER_REG, 0, UART_IER_RX_IE | UART_IER_OE_IE);
#endif
}

// Gửi 1 ký tự ra UART lên máy tính (kèm timeout chống treo)
int uart_putc(char c) {
    uint32_t timeout = 500000;
    // Đợi cờ tx_done (bit 0 của UART_STT_REG) lên 1 (TX rảnh)
    while (((IORD_32DIRECT(UART_STT_REG, 0) & UART_STT_TX_DONE) == 0) && --timeout);
    if (timeout == 0) return -1; // Quá thời gian chờ

    // Ghi byte ky tu vao TX FIFO (Phan cung tu dong truyen khi FIFO khong rong)
    IOWR_32DIRECT(UART_TX_DATA_REG, 0, (uint32_t)c);
    return 0;
}

// Kiểm tra xem có dữ liệu sẵn sàng không (Non-blocking, lấy từ Ring Buffer)
int uart_has_data(void) {
    // Nếu trong Ring Buffer đã có dữ liệu (do ngắt ISR nạp vào)
    if (ringbuf_available() > 0) return 1;

    // Chế độ dự phòng Fallback (hoạt động tốt ngay cả khi chưa bật ngắt IRQ)
    if (IORD_32DIRECT(UART_STT_REG, 0) & UART_STT_RX_DONE) {
        uint8_t ch = (uint8_t)(IORD_32DIRECT(UART_RX_DATA_REG, 0) & 0xFF);
        ringbuf_put(ch);
        return 1;
    }

    return 0;
}

// Đọc 1 ký tự từ UART
char uart_getc(void) {
    uint8_t ch = 0;
    while (!ringbuf_get(&ch)) {
        // Kiểm tra dự phòng nếu ngắt chưa kích hoạt
        if (uart_has_data()) {
            continue;
        }
    }
    return (char)ch;
}

// Gửi 1 chuỗi ký tự qua UART
void uart_puts(const char *s) {
    while (*s) {
        uart_putc(*s++);
    }
}

int main(void) {
    // 1. Khởi tạo UART 9600 baud và cấu hình ngắt IRQ
    uart_init();

    // 2. Hiển thị 00 lên 2 LED 7 đoạn HEX1-HEX0 lúc khởi động
    IOWR_ALTERA_AVALON_PIO_DATA(PIO_0_BASE, 0x00);

    // 3. Gửi lời chào lên terminal máy tính
    uart_puts("\r\n=== DE2-115 UART WITH INTERRUPT READY ===\r\n");

    uint8_t prev_key1 = 1;

    while (1) {
        // -------------------------------------------------------------
        // [A] CHẾ ĐỘ LOOPBACK TỰ ĐỘNG:
        // Đọc ký tự từ Ring Buffer (được nạp tự động qua ngắt ISR)
        // Echo lại TX về PC và xuất mã Hex ASCII ra LED 7 đoạn
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

            // Nhờ có Ngắt + Ring Buffer, việc delay 50ms này KHÔNG CÒN GÂY MẤT BYTE NỮA!
            delay_ms(50); // Chống dội phím (debounce)
        }
        prev_key1 = key1;
    }

    return 0;
}

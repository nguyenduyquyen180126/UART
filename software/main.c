#include <stdint.h>
#include <stdbool.h>
#include "uart_irq.h"
#include "uart_config.h"
#include "intel_niosv.h"
#include "sys/alt_irq.h"
#include "system.h"
#include "io.h"
#include "altera_avalon_pio_regs.h"
#include "altera_avalon_jtag_uart_regs.h"
#ifndef UART_WAIT_IRQ
#define UART_WAIT_IRQ() __asm__ volatile ("wfi")
#endif

// ==============================================================================
// 1. ĐỊNH NGHĨA ĐỊA CHỈ NGOẠI VI TRÊN BUS SOC
// ==============================================================================
#ifndef APB_UART_0_BASE
#define APB_UART_0_BASE   0x00020000 // Địa chỉ cơ sở của APB UART
#endif

#ifndef JTAG_UART_0_BASE
#define JTAG_UART_0_BASE  0x00010010 // Địa chỉ cơ sở của JTAG UART (Cáp USB-Blaster)
#endif

#ifndef PIO_0_BASE
#define PIO_0_BASE        0x00010000 // LED 7 đoạn HEX1-HEX0
#endif

#ifndef PIO_KEY_BASE
#define PIO_KEY_BASE 0x00010030 // Nút nhấn KEY[1]
#endif

// Offset các thanh ghi APB UART (khớp chuẩn với rtl/uart_regs.v)
#define UART_TX_DATA_REG  (APB_UART_0_BASE + 0x00) // Thanh ghi ghi dữ liệu phát
#define UART_RX_DATA_REG  (APB_UART_0_BASE + 0x04) // Thanh ghi đọc dữ liệu nhận
#define UART_CFG_REG      (APB_UART_0_BASE + 0x08) // Cấu hình baudrate và khung truyền
#define UART_STT_REG      (APB_UART_0_BASE + 0x0C) // Thanh ghi trạng thái (tx_ready, rx_ready, error, overrun, tx_full, rx_full)
#define UART_IER_REG      (APB_UART_0_BASE + 0x10) // Thanh ghi cho phép ngắt (rx_ie, tx_ie, oe_ie)

// Mặt nạ bit thanh ghi STT
#define UART_STT_TX_DONE  (1 << 0) // TX rảnh & TX FIFO rỗng
#define UART_STT_TX_READY (1 << 0) // Alias tương thích ngược
#define UART_STT_RX_DONE  (1 << 1) // RX FIFO có dữ liệu
#define UART_STT_ERROR    (1 << 2) // Lỗi Parity/Frame
#define UART_STT_OVERRUN  (1 << 3) // Lỗi Overrun
#define UART_STT_TX_FULL  (1 << 4) // TX FIFO đầy 16 byte
#define UART_STT_RX_FULL  (1 << 5) // RX FIFO đầy 16 byte

// Mặt nạ bit thanh ghi IER
#define UART_IER_RX_IE    (1 << 0) // Bit 0: Cho phép ngắt nhận RX
#define UART_IER_TX_IE    (1 << 1) // Bit 1: Cho phép ngắt phát TX
#define UART_IER_OE_IE    (1 << 2) // Bit 2: Cho phép ngắt lỗi Overrun

// Thống kê hoạt động của hệ thống
typedef struct {
    uint32_t apb_rx_bytes;
    uint32_t apb_tx_bytes;
    uint32_t jtag_rx_bytes;
    uint32_t jtag_tx_bytes;
    bool echo_enabled;
    bool direct_chat_mode;
} sys_stats_t;

static sys_stats_t g_stats = {0, 0, 0, 0, true, false};

#define CMD_BUF_SIZE 128
static char cmd_buf[CMD_BUF_SIZE];
static int  cmd_idx = 0;

#define PC_LINE_BUF_SIZE 128
static char pc_line_buf[PC_LINE_BUF_SIZE];
static int  pc_line_idx = 0;

// Khai báo trước các hàm phục vụ Full-Duplex
void jtag_puts(const char *s);
void jtag_putc(char c);
int  apb_uart_putc(char c);
void apb_uart_puts(const char *s);
bool apb_uart_has_data(void);
char apb_uart_getc(void);
void update_hex_display(uint8_t val);
void apb_uart_service_rx(void);
static bool config_command(const char *line, bool from_pc);
static void config_service(void);

// ==============================================================================
// 2. CÁC HÀM GIAO TIẾP VỚI JTAG UART (TERMINAL 1 - NIOS V CONSOLE)
// ==============================================================================
// Kiểm tra xem JTAG Console có ký tự gửi từ máy tính không (Non-blocking)
bool jtag_has_char(void) {
    uint32_t data_reg = IORD_ALTERA_AVALON_JTAG_UART_DATA(JTAG_UART_0_BASE);
    return (data_reg & ALTERA_AVALON_JTAG_UART_DATA_RVALID_MSK) ? true : false;
}

// Đọc 1 ký tự từ JTAG Console (trả về -1 nếu không có)
int jtag_getc_nonblock(void) {
    uint32_t data_reg = IORD_ALTERA_AVALON_JTAG_UART_DATA(JTAG_UART_0_BASE);
    if (data_reg & ALTERA_AVALON_JTAG_UART_DATA_RVALID_MSK) {
        g_stats.jtag_rx_bytes++;
        return (int)(data_reg & ALTERA_AVALON_JTAG_UART_DATA_DATA_MSK);
    }
    return -1;
}

// Gửi 1 ký tự ra JTAG Console (Kèm Timeout chống treo khi chưa cắm/mở Terminal 1)
void jtag_putc(char c) {
    uint32_t timeout = 50000;
    uint32_t ctrl;
    do {
        ctrl = IORD_ALTERA_AVALON_JTAG_UART_CONTROL(JTAG_UART_0_BASE);
        if ((ctrl & ALTERA_AVALON_JTAG_UART_CONTROL_WSPACE_MSK) != 0) {
            IOWR_ALTERA_AVALON_JTAG_UART_DATA(JTAG_UART_0_BASE, (uint32_t)c);
            g_stats.jtag_tx_bytes++;
            return;
        }
    } while (--timeout);
    // Khi hết timeout (Terminal JTAG chưa mở hoặc host không đọc),
    // bỏ qua ký tự một cách an toàn để KHÔNG làm treo cứng toàn bộ CPU Nios V!
}

// Gửi chuỗi ký tự ra JTAG Console
void jtag_puts(const char *s) {
    while (*s) {
        if (*s == '\n') jtag_putc('\r');
        jtag_putc(*s++);
    }
}

// In số nguyên ra JTAG Console
void jtag_put_uint(uint32_t n) {
    char buf[12];
    int i = 0;
    if (n == 0) {
        jtag_putc('0');
        return;
    }
    while (n > 0) {
        buf[i++] = (n % 10) + '0';
        n /= 10;
    }
    while (i > 0) {
        jtag_putc(buf[--i]);
    }
}

// In số Hex 32-bit ra JTAG Console
void jtag_put_hex32(uint32_t val) {
    const char hex_chars[] = "0123456789ABCDEF";
    jtag_puts("0x");
    for (int i = 7; i >= 0; i--) {
        jtag_putc(hex_chars[(val >> (i * 4)) & 0xF]);
    }
}

// ==============================================================================
// 3. CÁC HÀM GIAO TIẾP VỚI APB UART (TERMINAL 2 - PC SERIAL APP)
// ==============================================================================
// Khởi tạo APB UART: Baud 9600, 8 data bits, 1 stop bit, no parity
void apb_uart_init(void) {
    if (uart_irq_init() != 0) {
        jtag_puts("UART ISR registration failed\n");
        for (;;) { UART_WAIT_IRQ(); }
    }
}

// Xếp byte vào TX queue; ISR tiếp tục truyền khi UART hoàn tất burst.
int apb_uart_putc(char c) {
    while (uart_irq_putc((uint8_t)c) != 0) {
        /* Queue backpressure: the ISR advances TX; do not poll MMIO. */
        UART_WAIT_IRQ();
    }
    g_stats.apb_tx_bytes++;
    return 0;
}

// Gửi chuỗi ký tự qua APB UART
void apb_uart_puts(const char *s) {
    while (*s) {
        apb_uart_putc(*s++);
    }
}

// Kiểm tra APB UART có byte nhận từ PC không
bool apb_uart_has_data(void) {
    return uart_irq_rx_pending();
}

// Lấy byte từ RX queue trong RAM; chỉ ISR đọc/pop RX FIFO phần cứng.
char apb_uart_getc(void) {
    g_stats.apb_rx_bytes++;
    return (char)uart_irq_getc();
}

// Cập nhật LED 7 thanh HEX1-HEX0
void update_hex_display(uint8_t val) {
    IOWR_ALTERA_AVALON_PIO_DATA(PIO_0_BASE, val);
}

// Xử lý 1 ký tự nhận được từ PC theo chuẩn Cách B (Gom chuỗi)
static void handle_pc_rx_char(char pc_char) {
    static char s_prev_pc_char = 0;

    // 1. Cập nhật mã ASCII lên 2 LED 7 đoạn HEX1-HEX0 ngay khi nhận
    update_hex_display((uint8_t)pc_char);

    // Chống xử lý trùng lặp khi PC gửi liên tiếp CRLF (\r\n)
    if (pc_char == '\n' && s_prev_pc_char == '\r') {
        s_prev_pc_char = pc_char;
        return; // Bỏ qua ký tự \n đi liền sau \r để tránh echo 2 lần xuống dòng
    }
    s_prev_pc_char = pc_char;

    // 2. Xử lý kết thúc dòng khi người dùng nhấn Enter (\r hoặc \n) từ PC
    if (pc_char == '\r' || pc_char == '\n') {
        if (g_stats.echo_enabled) {
            apb_uart_puts("\r\n");
        }

        // Nếu trong bộ đệm có nội dung chuỗi
        if (pc_line_idx > 0) {
            pc_line_buf[pc_line_idx] = '\0';
            if (pc_line_buf[0] == '@' && config_command(pc_line_buf + 1, true)) {
                pc_line_idx = 0;
                return;
            }

            jtag_puts("\r\n[Incoming from PC (APB)]: \"");
            jtag_puts(pc_line_buf);
            jtag_puts("\"\r\n");

            // Phục hồi lại dấu nhắc lệnh CLI và ký tự người dùng đang gõ dở trên JTAG
            if (!g_stats.direct_chat_mode) {
                jtag_puts("NIOS-V:/> ");
                if (cmd_idx > 0) {
                    for (int i = 0; i < cmd_idx; i++) {
                        jtag_putc(cmd_buf[i]);
                    }
                }
            }

            pc_line_idx = 0; // Đặt lại chỉ số bộ đệm cho câu tiếp theo
        }
    }
    // 3. Xử lý phím Backspace từ PC (\b hoặc ASCII 127 Delete)
    else if (pc_char == '\b' || pc_char == 127) {
        if (pc_line_idx > 0) {
            pc_line_idx--;
            if (g_stats.echo_enabled) {
                apb_uart_puts("\b \b");
            }
        }
    }
    // 4. Gom ký tự thường vào bộ đệm dòng (có chống tràn bộ đệm)
    else if (pc_line_idx < PC_LINE_BUF_SIZE - 1) {
        pc_line_buf[pc_line_idx++] = pc_char;
        if (g_stats.echo_enabled) {
            apb_uart_putc(pc_char);
        }
    }
}

// Hàm phục vụ kênh RX từ PC (có bảo vệ chống gọi đệ quy khi echo)
void apb_uart_service_rx(void) {
    static bool s_in_rx_service = false;
    if (s_in_rx_service) return; // Chống re-entrancy

    s_in_rx_service = true;
    while (apb_uart_has_data()) {
        char pc_char = apb_uart_getc();
        handle_pc_rx_char(pc_char);
    }
    s_in_rx_service = false;
}

// ==============================================================================
// 4. TIỆN ÍCH XỬ LÝ CHUỖI NHỎ GỌN (STRING UTILITIES)
// ==============================================================================
int str_len(const char *s) {
    int len = 0;
    while (*s++) len++;
    return len;
}

bool str_equals(const char *s1, const char *s2) {
    while (*s1 && (*s1 == *s2)) {
        s1++;
        s2++;
    }
    return (*s1 == '\0' && *s2 == '\0');
}

bool str_starts(const char *str, const char *prefix) {
    while (*prefix) {
        if (*str++ != *prefix++) return false;
    }
    return true;
}

uint32_t parse_hex(const char *s) {
    uint32_t res = 0;
    while (*s == ' ') s++; // Bỏ qua khoảng trắng đầu dòng
    if (s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) s += 2;
    while (*s) {
        char c = *s++;
        if (c >= '0' && c <= '9') res = (res << 4) + (c - '0');
        else if (c >= 'a' && c <= 'f') res = (res << 4) + (c - 'a' + 10);
        else if (c >= 'A' && c <= 'F') res = (res << 4) + (c - 'A' + 10);
        else break;
    }
    return res;
}

/* Runtime CFG change. The peer must stop transmitting after the command.
 * ACK goes at OLD settings; CFG changes only after TX-complete IRQ and 50 ms
 * RX quiet, with a 200 ms grace. Main continues draining RX while waiting.
 * Hardware does not expose rx_busy: uncoordinated TX during the final CFG write
 * is unsupported (RTL rejects CFG during an in-flight frame with PSLVERR). */
static bool config_pending;
static uint8_t pending_config;
static uint32_t config_rx_seen;
static uint64_t config_started, config_quiet;
static void config_reply(const char *message, bool from_pc) {
    jtag_puts(message);
    if (from_pc) apb_uart_puts(message);
}
static bool config_command(const char *line, bool from_pc) {
    uint8_t value;
    int action = uart_config_parse(line, uart_irq_config(), &value);
    if (!action) return false;
    if (action < 0) {
        config_reply("\r\nERR: config <2400|4800|9600|19200> <5..8><N|E|O><1|2>; baud <rate>\r\n", from_pc);
        return true;
    }
    if (from_pc && action == 1 && (value & 3u) < 2u) {
        config_reply("\r\nERR: Terminal 2 commands require 7/8 data bits; use Terminal 1 for 5/6 bits.\r\n", true);
        return true;
    }
    char description[16];
    uart_config_format(value, description);
    if (action == 2) {
        config_reply("\r\nCONFIG ", from_pc);
        config_reply(description, from_pc);
        config_reply("\r\n", from_pc);
        return true;
    }
    if (config_pending) {
        config_reply("\r\nBUSY: configuration change pending\r\n", from_pc);
        return true;
    }
    config_reply("\r\nSWITCH ", from_pc);
    config_reply(description, from_pc);
    config_reply("; stop PC TX. Wait APPLIED on Terminal 1, then change PC settings.\r\n", from_pc);
    pending_config = value;
    config_rx_seen = uart_rx_count;
    config_started = config_quiet = alt_niosv_mtime_get();
    config_pending = true;
    return true;
}
static void config_service(void) {
    if (!config_pending) return;
    uint64_t now = alt_niosv_mtime_get();
    if (uart_rx_count != config_rx_seen) {
        config_rx_seen = uart_rx_count;
        config_quiet = now;
    }
    if (now - config_started > 2ull * ALT_CPU_CPU_FREQ) {
        config_pending = false;
        jtag_puts("\r\nCFG BUSY/TIMEOUT: unchanged; stop traffic and retry.\r\nNIOS-V:/> ");
        return;
    }
    if (now - config_started < ALT_CPU_CPU_FREQ / 5u ||
        now - config_quiet < ALT_CPU_CPU_FREQ / 20u || uart_irq_tx_busy()) return;
    if (uart_irq_configure_idle(pending_config)) return;
    config_pending = false;
    char description[16];
    uart_config_format(pending_config, description);
    jtag_puts("\r\nAPPLIED "); jtag_puts(description);
    jtag_puts("; now update PC serial settings.\r\nNIOS-V:/> ");
}

// ==============================================================================
// 5. TRÌNH PHÂN TÍCH LỆNH COMMAND SHELL (CLI PARSER TRÊN JTAG CONSOLE)
// ==============================================================================
void print_banner(void) {
    jtag_puts("\r\n");
    jtag_puts("====================================================================\r\n");
    jtag_puts("     TERASIC DE2-115 NIOS-V SoC DUAL-CPU INTERCONNECT BRIDGE        \r\n");
    jtag_puts("       Architecture: RISC-V RV32I @ 50MHz  |  Bus: AMBA APB         \r\n");
    jtag_puts("====================================================================\r\n");
    jtag_puts(" [Core]  Nios V CPU online. Running on-chip RAM 64KB.\r\n");
    jtag_puts(" [APB]   UART IP Peripheral initialized at base: 0x00020000.\r\n");
    jtag_puts(" [Mode]  Full-Duplex Symmetric String Communication (Cach B).\r\n");
    jtag_puts(" [JTAG]  Interactive Debug Shell active.\r\n");
    jtag_puts("--------------------------------------------------------------------\r\n");
    jtag_puts(" Type 'help' to see available commands, or 'send <msg>' to talk to PC.\r\n");
    jtag_puts("====================================================================\r\n");
    jtag_puts("NIOS-V:/> ");
}

void print_help(void) {
    jtag_puts("\r\n--- DANH SACH LENH HE THONG NIOS-V SHELL ---\r\n");
    jtag_puts("  config [baud format]: Doc/doi UART, vd config 19200 8E2\r\n");
    jtag_puts("  baud <rate>         : Doi baud, giu data/parity/stop\r\n");
    jtag_puts("  Terminal 2          : @config 19200 8N1 / @baud 9600 / @config\r\n");
    jtag_puts("  help                : Hien thi bang tro giup nay\r\n");
    jtag_puts("  send <message>      : Gui tin nhan chuoi qua bus APB sang Terminal PC\r\n");
    jtag_puts("  chat                : Bat/tat che do go truc tiep (Direct Chat Mode)\r\n");
    jtag_puts("  irq                 : Xem ISR calls, RX errors va dropped bytes\r\n");
    jtag_puts("  status              : Xem thong ke byte truyen/nhan & trang thai bus\r\n");
    jtag_puts("  peek <08/0C/10>      : Doc CFG/STT/IER; RX do ISR quan ly\r\n");
    jtag_puts("  poke 00 <val>       : Gui byte qua hang doi IRQ (Vi du: poke 00 41)\r\n");
    jtag_puts("  hex <val_hex>       : Dat so hien thi tren LED 7 thanh HEX1-HEX0\r\n");
    jtag_puts("  echo <on/off>       : Bat/tat che do tu dong echo tin nhan tu PC\r\n");
    jtag_puts("  clear               : Xoa man hinh Terminal JTAG\r\n");
    jtag_puts("--------------------------------------------\r\n");
}

void execute_command(char *cmd) {
    while (*cmd == ' ') cmd++; // Bỏ qua khoảng trắng đầu dòng

    if (cmd[0] == '\0') {
        jtag_puts("NIOS-V:/> ");
        return;
    }

    if (config_command(cmd, false)) {
        /* Handled by the shared runtime configuration parser. */
    }
    else if (str_equals(cmd, "help")) {
        print_help();
    }
    else if (str_starts(cmd, "send")) {
        const char *msg = cmd + 4;
        while (*msg == ' ') msg++;
        if (*msg == '\0') {
            jtag_puts("\r\n[Usage]: send <message>\r\n");
        } else {
            apb_uart_puts(msg);
            apb_uart_puts("\r\n");

            jtag_puts("\r\n[CPU -> PC via APB]: \"");
            jtag_puts(msg);
            jtag_puts("\" (Sent successfully)\r\n");
        }
    }
    else if (str_equals(cmd, "chat")) {
        g_stats.direct_chat_mode = !g_stats.direct_chat_mode;
        jtag_puts("\r\n[System] Direct Chat Mode: ");
        jtag_puts(g_stats.direct_chat_mode ? "ENABLED (Moi ky tu go se ban truc tiep sang PC! Go ESC de thoat)\r\n" : "DISABLED (Tro ve che do CLI Shell)\r\n");
    }
    else if (str_equals(cmd, "status")) {
        jtag_puts("\r\n=== TRANG THAI HE THONG SoC & BUS APB ===\r\n");
        jtag_puts(" - APB UART Rx (nhan tu PC)   : "); jtag_put_uint(g_stats.apb_rx_bytes); jtag_puts(" bytes\r\n");
        jtag_puts(" - APB UART Tx (gui sang PC)  : "); jtag_put_uint(g_stats.apb_tx_bytes); jtag_puts(" bytes\r\n");
        jtag_puts(" - JTAG UART Rx (nhan tu CLI) : "); jtag_put_uint(g_stats.jtag_rx_bytes); jtag_puts(" bytes\r\n");
        jtag_puts(" - JTAG UART Tx (xuat ra CLI) : "); jtag_put_uint(g_stats.jtag_tx_bytes); jtag_puts(" bytes\r\n");
        jtag_puts(" - Echo loopback status       : "); jtag_puts(g_stats.echo_enabled ? "ON\r\n" : "OFF\r\n");
        jtag_puts(" - Thanh ghi STT (0x2000C)    : "); jtag_put_hex32(IORD_32DIRECT(UART_STT_REG, 0)); jtag_puts("\r\n");
        jtag_puts(" - Thanh ghi CFG (0x20008)    : "); jtag_put_hex32(IORD_32DIRECT(UART_CFG_REG, 0)); jtag_puts("\r\n");
        jtag_puts("=========================================\r\n");
    }
    else if (str_equals(cmd, "irq")) {
        jtag_puts("\r\nUART ISR calls: "); jtag_put_uint(uart_irq_count);
        jtag_puts(" RX: "); jtag_put_uint(uart_rx_count);
        jtag_puts(" dropped: "); jtag_put_uint(uart_rx_dropped);
        jtag_puts(" errors: "); jtag_put_uint(uart_rx_errors);
        jtag_puts(" overruns: "); jtag_put_uint(uart_rx_overruns);
        jtag_puts("\r\n");
    }
    else if (str_starts(cmd, "peek")) {
        const char *p = cmd + 4;
        while (*p == ' ') p++;
        uint32_t offset = parse_hex(p);
        uint32_t reg_off = offset & 0xFFC;
        if (reg_off != 8 && reg_off != 12 && reg_off != 16) {
            jtag_puts("\r\nUse peek 08/0C/10; RX is owned by ISR.\r\nNIOS-V:/> ");
            return;
        }
        uint32_t addr = APB_UART_0_BASE + reg_off;
        uint32_t val = IORD_32DIRECT(addr, 0);
        jtag_puts("\r\n[APB Read] Addr: "); jtag_put_hex32(addr);
        jtag_puts(" => Data: "); jtag_put_hex32(val); jtag_puts("\r\n");
    }
    else if (str_starts(cmd, "poke")) {
        const char *p = cmd + 4;
        while (*p == ' ') p++;
        uint32_t offset = parse_hex(p);
        while (*p && *p != ' ') p++;
        while (*p == ' ') p++;
        uint32_t val = parse_hex(p);
        uint32_t reg_off = offset & 0xFFC;

        // ISR sở hữu CFG/IER/RX; chỉ cho phép gửi TX qua hàng đợi.
        if (reg_off != 0x00) {
            jtag_puts("\r\n[Error] Only poke 00 is allowed while the IRQ driver owns CFG/IER/RX/STT.\r\n");
        } else {
            uint32_t addr = APB_UART_0_BASE + reg_off;
            apb_uart_putc((char)val);
            jtag_puts("\r\n[APB Write] Addr: "); jtag_put_hex32(addr);
            jtag_puts(" <= Data: "); jtag_put_hex32(val); jtag_puts("\r\n");
        }
    }
    else if (str_starts(cmd, "hex")) {
        const char *p = cmd + 3;
        while (*p == ' ') p++;
        uint32_t val = parse_hex(p);
        update_hex_display((uint8_t)val);
        jtag_puts("\r\n[LED 7-Seg] Updated HEX1-HEX0 = ");
        jtag_put_hex32(val & 0xFF); jtag_puts("\r\n");
    }
    else if (str_starts(cmd, "echo")) {
        const char *p = cmd + 4;
        while (*p == ' ') p++;
        if (str_equals(p, "on")) {
            g_stats.echo_enabled = true;
            jtag_puts("\r\n[Echo] Enabled auto-echo to PC.\r\n");
        } else if (str_equals(p, "off")) {
            g_stats.echo_enabled = false;
            jtag_puts("\r\n[Echo] Disabled auto-echo to PC.\r\n");
        } else {
            jtag_puts("\r\nUsage: echo on / echo off\r\n");
        }
    }
    else if (str_equals(cmd, "clear")) {
        jtag_puts("\033[2J\033[H");
    }
    else {
        jtag_puts("\r\n[Error] Unknown command: '");
        jtag_puts(cmd);
        jtag_puts("'. Type 'help' for command list.\r\n");
    }

    if (!g_stats.direct_chat_mode) {
        jtag_puts("NIOS-V:/> ");
    }
}

// ==============================================================================
// 6. CHƯƠNG TRÌNH CHÍNH (MAIN DISPATCHER LOOP)
// ==============================================================================
int main(void) {
    // 1. Khởi tạo phần cứng ngoại vi
    apb_uart_init();
    update_hex_display(0x00); // Khởi động hiển thị 00 trên HEX1-HEX0

    // 2. In lời chào mừng ra JTAG Console (Terminal 1)
    print_banner();

    // 3. Gửi thông báo khởi động ra APB UART (Terminal 2 của PC)
    apb_uart_puts("\r\n========================================================\r\n");
    apb_uart_puts(" [DE2-115 SoC Online] Nios V RISC-V | APB UART 9600-8N1\r\n");
    apb_uart_puts(" Mode: Full-Duplex String Messaging (Cach B: String-to-String)\r\n");
    apb_uart_puts("========================================================\r\n\r\n");

    char prev_jtag_ch = 0;

    while (1) {
        config_service();
        // ----------------------------------------------------------------------
        // [LUỒNG 1]: KIỂM TRA DỮ LIỆU TỪ TERMINAL 1 (JTAG CONSOLE)
        // ----------------------------------------------------------------------
        int c = jtag_getc_nonblock();
        if (c != -1) {
            char ch = (char)c;

            // Chống xử lý trùng lặp CRLF (\r\n) từ Terminal JTAG
            if (ch == '\n' && prev_jtag_ch == '\r') {
                prev_jtag_ch = ch;
                continue; // Bỏ qua ký tự \n đi liền sau \r
            }
            prev_jtag_ch = ch;

            // Chế độ Direct Chat: Gõ ký tự nào thì bắn thẳng qua APB sang PC
            if (g_stats.direct_chat_mode) {
                if (ch == 27) { // Phím ESC -> Thoát chat mode
                    g_stats.direct_chat_mode = false;
                    jtag_puts("\r\n[System] Exited Direct Chat Mode.\r\nNIOS-V:/> ");
                } else if (ch == '\b' || ch == 127) { // Phím Backspace trong chat mode
                    apb_uart_puts("\b \b");
                    jtag_puts("\b \b");
                } else {
                    apb_uart_putc(ch);
                    jtag_putc(ch); // Local echo trên Terminal 1
                    if (ch == '\r') {
                        apb_uart_putc('\n');
                        jtag_putc('\n');
                    }
                }
            }
            // Chế độ CLI Shell
            else {
                if (ch == '\r' || ch == '\n') {
                    jtag_puts("\r\n");
                    cmd_buf[cmd_idx] = '\0';
                    execute_command(cmd_buf);
                    cmd_idx = 0;
                }
                else if (ch == '\b' || ch == 127) { // Xử lý phím Backspace
                    if (cmd_idx > 0) {
                        cmd_idx--;
                        jtag_puts("\b \b");
                    }
                }
                else if (cmd_idx < CMD_BUF_SIZE - 1) {
                    cmd_buf[cmd_idx++] = ch;
                    jtag_putc(ch); // Echo lại màn hình để người dùng thấy phím vừa gõ
                }
            }
        }

        // ----------------------------------------------------------------------
        // [LUỒNG 2]: KIỂM TRA DỮ LIỆU TỪ TERMINAL 2 (PC SERIAL QUA APB UART)
        // [CÁCH B & FULL-DUPLEX]: GOM CHUỖI ĐỐI XỨNG & ĐỒNG THỜI VỚI TRUYỀN TX
        // ----------------------------------------------------------------------
        if (apb_uart_has_data()) {
            apb_uart_service_rx();
        }
    }

    return 0;
}

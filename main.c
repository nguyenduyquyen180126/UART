#include <stdint.h>
#include <stdbool.h>
#include "system.h"
#include "io.h"
#include "altera_avalon_pio_regs.h"
#include "altera_avalon_jtag_uart_regs.h"

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
    uint32_t timeout = 100000;
    // Chờ TX rảnh trước khi nạp cấu hình CFG để thỏa mãn uart_idle trong RTL
    while (((IORD_32DIRECT(UART_STT_REG, 0) & UART_STT_TX_DONE) == 0) && --timeout);
    IOWR_32DIRECT(UART_CFG_REG, 0, (0x2 << 5) | 0x3);
}

// Gửi 1 ký tự ra APB UART (Kèm cơ chế Full-Duplex Interleaved Service & Timeout)
int apb_uart_putc(char c) {
    uint32_t timeout = 500000;
    while (((IORD_32DIRECT(UART_STT_REG, 0) & UART_STT_TX_FULL) != 0) && --timeout) {
        // [FULL-DUPLEX]: Trong khi CPU chờ TX FIFO có chỗ trống,
        // nếu PC cùng lúc bắn byte vào RX, CPU xen kẽ đọc và lưu vào bộ đệm ngay!
        apb_uart_service_rx();
    }
    if (timeout == 0) return -1;

    // Ghi byte vào TX FIFO (Hardware tự động kích phát start_tx = !empty)
    IOWR_32DIRECT(UART_TX_DATA_REG, 0, (uint32_t)c);
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
    return (IORD_32DIRECT(UART_STT_REG, 0) & UART_STT_RX_DONE) ? true : false;
}

// Đọc 1 ký tự từ APB UART (phần cứng tự pop 1 byte khỏi RX FIFO và xóa cờ Overrun)
char apb_uart_getc(void) {
    g_stats.apb_rx_bytes++;
    return (char)(IORD_32DIRECT(UART_RX_DATA_REG, 0) & 0xFF);
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
    jtag_puts("  help                : Hien thi bang tro giup nay\r\n");
    jtag_puts("  send <message>      : Gui tin nhan chuoi qua bus APB sang Terminal PC\r\n");
    jtag_puts("  chat                : Bat/tat che do go truc tiep (Direct Chat Mode)\r\n");
    jtag_puts("  status              : Xem thong ke byte truyen/nhan & trang thai bus\r\n");
    jtag_puts("  peek <offset_hex>   : Doc thanh ghi APB UART (Vi du: peek 0x0C)\r\n");
    jtag_puts("  poke <offset> <val> : Ghi thanh ghi APB UART (Vi du: poke 0x00 0x41)\r\n");
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

    if (str_equals(cmd, "help")) {
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
    else if (str_starts(cmd, "peek")) {
        const char *p = cmd + 4;
        while (*p == ' ') p++;
        uint32_t offset = parse_hex(p);
        uint32_t reg_off = offset & 0xFFC;
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

        // Chốt an toàn: Chặn ghi vào offset 0x0C (UART_STT_REG là read-only, ghi sẽ gây lỗi bus SLVERR)
        if (reg_off == 0x0C) {
            jtag_puts("\r\n[Error] Offset 0x0C (UART_STT_REG) is read-only and causes bus exception if written!\r\n");
        } else {
            uint32_t addr = APB_UART_0_BASE + reg_off;
            IOWR_32DIRECT(addr, 0, val);
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

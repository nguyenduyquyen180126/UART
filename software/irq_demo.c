/* HEX3:HEX2 = decimal 00..60. UART RX/TX are served by real platform IRQ 0.
 * After RX, freeze the existing value and fractional second, echo each byte,
 * hold for one second so the pause is visible, then continue from that value. */
#include <stdint.h>
#include "system.h"
#include "io.h"
#include "sys/alt_irq.h"
#include "intel_niosv.h"
#include "altera_avalon_jtag_uart_regs.h"
#include "uart_irq.h"
#include "demo_clock.h"
static volatile demo_clock_t clock_state = {0, 0, 0, true};
static volatile uint32_t timer_ticks;

void uart_irq_received(uint8_t byte) {
    (void)byte;
    demo_clock_receive(&clock_state);
}
static void timer_isr(alt_u32 cause, alt_u32 epc, alt_u32 tval) {
    (void)cause; (void)epc; (void)tval;
    alt_niosv_mtimecmp_set(alt_niosv_mtime_get() + ALT_CPU_CPU_FREQ / 100u);
    ++timer_ticks;
    demo_clock_tick(&clock_state, uart_irq_tx_busy() || uart_irq_rx_pending());
}
/* Diagnostic console is optional. Never wait for a JTAG terminal. */
static void log_text(const char *text) {
    while (*text) {
        if (!(IORD_ALTERA_AVALON_JTAG_UART_CONTROL(JTAG_UART_0_BASE) &
              ALTERA_AVALON_JTAG_UART_CONTROL_WSPACE_MSK)) return;
        IOWR_ALTERA_AVALON_JTAG_UART_DATA(JTAG_UART_0_BASE, *text++);
    }
}
static void log_hex(uint32_t value) {
    char text[9];
    for (unsigned i = 0; i < 8; ++i) text[i] = "0123456789ABCDEF"[(value >> (28-4*i)) & 15];
    text[8] = 0;
    log_text(text);
}
int main(void) {
    alt_irq_context saved = alt_irq_disable_all();
    IOWR_32DIRECT(PIO_HEX_BASE, 0, 0);
    if (uart_irq_init()) {
        IOWR_32DIRECT(PIO_0_BASE, 0, 0xEE);
        for (;;) {}
    }
    /* This standalone demo owns mtime; no HAL alarms/stdio are used. */
    alt_niosv_disable_timer_interrupt();
    alt_niosv_register_mtimecmp_interrupt_handle(timer_isr);
    alt_niosv_mtimecmp_set(alt_niosv_mtime_get() + ALT_CPU_CPU_FREQ / 100u);
    alt_niosv_enable_timer_interrupt();
    alt_irq_enable_all(saved);
    log_text("\r\nIRQ DEMO: HEX3:HEX2=00..60; RX freezes+echoes; resumes after 1s.\r\n");
    for (;;) {
        int byte;
        while ((byte = uart_irq_getc()) >= 0) {
            IOWR_32DIRECT(PIO_0_BASE, 0, (uint8_t)byte);
            /* One TX byte per RX byte. Queue overload is counted by RX stats. */
            while (uart_irq_putc((uint8_t)byte)) __asm__ volatile ("wfi");
            log_text("RX="); log_hex((uint8_t)byte);
            log_text(" seconds="); log_hex(clock_state.seconds);
            log_text(" ISR="); log_hex(uart_irq_count);
            log_text(" ticks="); log_hex(timer_ticks); log_text("\r\n");
        }
        saved = alt_irq_disable_all();
        if (clock_state.changed) {
            IOWR_32DIRECT(PIO_HEX_BASE, 0, ((clock_state.seconds / 10u) << 4) | (clock_state.seconds % 10u));
            clock_state.changed = false;
        }
        /* Mask-test-WFI avoids sleeping after an RX event raced the test.
         * RISC-V WFI wakes on a locally enabled pending IRQ even with MIE=0. */
        if (!uart_irq_rx_pending()) __asm__ volatile ("wfi");
        alt_irq_enable_all(saved);
    }
}

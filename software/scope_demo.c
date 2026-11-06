/* Standalone scope demo: fixed 'A' on APB UART TX, 9600 8N1.
 * Reuses the existing IRQ driver and mtime; no RTL or timer ISR changes.
 * JTAG is diagnostic only. printf() would use the BSP's JTAG stdout, so the
 * explicit print_uart() below sends the character to the physical UART. */
#include <stdint.h>
#include "system.h"
#include "io.h"
#include "sys/alt_irq.h"
#include "intel_niosv.h"
#include "altera_avalon_jtag_uart_regs.h"
#include "uart_irq.h"

#define SCOPE_GAP_MS 5u
#ifndef SCOPE_MTIME_NOW
#define SCOPE_MTIME_NOW() alt_niosv_mtime_get()
#endif

static void log_text(const char *text) {
    while (*text) {
        if (!(IORD_ALTERA_AVALON_JTAG_UART_CONTROL(JTAG_UART_0_BASE) &
              ALTERA_AVALON_JTAG_UART_CONTROL_WSPACE_MSK)) return;
        IOWR_ALTERA_AVALON_JTAG_UART_DATA(JTAG_UART_0_BASE, *text++);
    }
}
static void discard_rx(void) {
    /* Incoming PC data must never be echoed onto this fixed-pattern output. */
    while (uart_irq_getc() >= 0) {}
}
static void print_uart(const char *text) {
    while (*text) {
        while (uart_irq_putc((uint8_t)*text)) discard_rx();
        ++text;
    }
}
static void delay_ms(unsigned milliseconds) {
    uint64_t ticks = (uint64_t)ALT_CPU_CPU_FREQ * milliseconds / 1000u;
    uint64_t start = SCOPE_MTIME_NOW();
    while (SCOPE_MTIME_NOW() - start < ticks) discard_rx();
}
static void scope_demo_cycle(void) {
    print_uart("A"); /* Exactly one byte 0x41; no CR/LF or other TX text. */
    /* Driver state is completed by the real TX IRQ. Busy wait avoids a WFI
     * lost-wakeup race and needs no periodic timer interrupt for the delay. */
    while (uart_irq_tx_busy()) discard_rx();
    delay_ms(SCOPE_GAP_MS); /* At least 5 ms idle AFTER the stop bit finishes. */
}
int main(void) {
    alt_irq_context saved = alt_irq_disable_all();
    if (uart_irq_init()) {
        log_text("\r\nSCOPE DEMO ERROR: UART IRQ registration failed.\r\n");
        while (1) {}
    }
    IOWR_32DIRECT(PIO_0_BASE, 0, 0x41); /* HEX1:HEX0 = 41 (ASCII A). */
    IOWR_32DIRECT(PIO_HEX_BASE, 0, 0);
    alt_irq_enable_all(saved);
    log_text("\r\nSCOPE DEMO: UART TX = A (0x41), 9600 8N1, 5 ms idle gap.\r\n");
    while (1) {
        scope_demo_cycle();
    }
}

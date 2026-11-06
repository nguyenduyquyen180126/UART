#include "system.h"
#include "io.h"
#include "sys/alt_irq.h"
#include "uart_irq.h"

#if !defined(APB_UART_0_IRQ) || APB_UART_0_IRQ < 0
#error APB UART must have a real CPU interrupt connection
#endif
#define RX_READY 2u
#define TX_IDLE 1u
#define TX_FULL 16u
#define OVERRUN 8u
#define RX_IE 1u
#define TX_IE 2u
#define CAPACITY 256u
#define MASK (CAPACITY - 1u)
static uint8_t rx_queue[CAPACITY], tx_queue[CAPACITY];
static volatile unsigned rx_head, rx_tail, tx_head, tx_tail;
static volatile bool tx_active;
volatile uint32_t uart_irq_count, uart_rx_count, uart_tx_count;
volatile uint32_t uart_rx_dropped, uart_rx_errors, uart_rx_overruns;
__attribute__((weak)) void uart_irq_received(uint8_t byte) { (void)byte; }
static uint32_t read_reg(unsigned offset) { return IORD_32DIRECT(APB_UART_0_BASE, offset); }
static void write_reg(unsigned offset, uint32_t value) { IOWR_32DIRECT(APB_UART_0_BASE, offset, value); }

/* Called only with interrupts masked. TX IRQ means shifter AND FIFO empty,
 * not FIFO space available. Feed a bounded burst, then wait for the idle IRQ.
 * Never leave TX_IE set when there is no work: idle is a level, not a pulse. */
static void start_tx(void) {
    unsigned budget = 16;
    while (tx_tail != tx_head && budget-- && !(read_reg(12) & TX_FULL)) {
        write_reg(0, tx_queue[tx_tail]);
        tx_tail = (tx_tail + 1u) & MASK;
        ++uart_tx_count;
        tx_active = true;
    }
    write_reg(16, RX_IE | (tx_active ? TX_IE : 0u));
}
static void uart_isr(void *context) {
    (void)context;
    ++uart_irq_count;
    uint32_t status = read_reg(12);
    if (status & OVERRUN) ++uart_rx_overruns;
    /* Drain the hardware FIFO in the ISR. Main never polls UART RX status.
     * RX_DATA read pops one entry and acknowledges the RX level naturally. */
    while (status & RX_READY) {
        uint32_t entry = read_reg(4);
        unsigned next = (rx_head + 1u) & MASK;
        ++uart_rx_count;
        uart_irq_received((uint8_t)entry);
        if (entry & 0x100u) ++uart_rx_errors;
        if (next == rx_tail) ++uart_rx_dropped;
        else {
            rx_queue[rx_head] = (uint8_t)entry;
            rx_head = next;
        }
        status = read_reg(12);
    }
    if (tx_active && (status & TX_IDLE)) {
        tx_active = false;
        start_tx();
    }
}
int uart_irq_init(void) {
    write_reg(16, 0);
    /* At boot the UART is idle; configure before enabling the receiver. */
    write_reg(8, 0x43u); /* 9600 8N1 */
    int rc = alt_ic_isr_register(APB_UART_0_IRQ_INTERRUPT_CONTROLLER_ID,
                                APB_UART_0_IRQ, uart_isr, 0, 0);
    if (rc) return rc;
    write_reg(16, RX_IE);
    return 0;
}
bool uart_irq_rx_pending(void) { return rx_head != rx_tail; }
int uart_irq_getc(void) {
    alt_irq_context saved = alt_irq_disable_all();
    int result = -1;
    if (rx_tail != rx_head) {
        result = rx_queue[rx_tail];
        rx_tail = (rx_tail + 1u) & MASK;
    }
    alt_irq_enable_all(saved);
    return result;
}
int uart_irq_putc(uint8_t byte) {
    alt_irq_context saved = alt_irq_disable_all();
    unsigned next = (tx_head + 1u) & MASK;
    if (next == tx_tail) { alt_irq_enable_all(saved); return -1; }
    tx_queue[tx_head] = byte;
    tx_head = next;
    if (!tx_active) start_tx();
    alt_irq_enable_all(saved);
    return 0;
}
bool uart_irq_tx_busy(void) { return tx_active || tx_tail != tx_head; }

uint8_t uart_irq_config(void) { return (uint8_t)read_reg(8); }
int uart_irq_configure_idle(uint8_t config) {
    if (config & 0x80u) return -1;
    alt_irq_context saved = alt_irq_disable_all();
    /* Never reconfigure while software TX or received data is outstanding.
     * RTL also requires !rx_busy, which STT does not expose. The shell's
     * peer-silence protocol and quiet interval are therefore mandatory. */
    uint32_t status = read_reg(12);
    if (tx_active || tx_head != tx_tail || rx_head != rx_tail ||
        !(status & TX_IDLE) || (status & RX_READY)) {
        alt_irq_enable_all(saved);
        return -1;
    }
    write_reg(8, config);
    int rc = read_reg(8) == config ? 0 : -1;
    alt_irq_enable_all(saved);
    return rc;
}

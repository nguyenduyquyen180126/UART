/* Execute the real scope cycle with modeled driver completion and mtime.
 * Confirms A-only output and delay starts after TX-complete, not enqueue. */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdbool.h>
#define PIO_0_BASE 0x10000u
#define PIO_HEX_BASE 0x10040u
#define JTAG_UART_0_BASE 0x10010u
static uint64_t scope_test_now(void);
#define SCOPE_MTIME_NOW() scope_test_now()
#define main scope_firmware_main
#include "../software/scope_demo.c"
#undef main
static uint64_t now, completed;
static unsigned sent, busy_checks, retries, drained;
static bool retry_once = true;
static uint64_t scope_test_now(void) {now+=10000;return now;}
uint32_t mock_read(unsigned base,unsigned off) {(void)base;(void)off;return 0xffff0000u;}
void mock_write(unsigned base,unsigned off,uint32_t value) {(void)base;(void)off;(void)value;}
alt_irq_context alt_irq_disable_all(void) {return 0;}
void alt_irq_enable_all(alt_irq_context state) {(void)state;}
int uart_irq_init(void) {return 0;}
int uart_irq_getc(void) {++drained;return drained%3==0 ? 0x5a : -1;}
int uart_irq_putc(uint8_t byte) {
    assert(byte=='A');
    if(retry_once) {retry_once=false;++retries;return -1;}
    ++sent;busy_checks=0;return 0;
}
bool uart_irq_tx_busy(void) {
    now+=50000; /* Fake finite TX in progress, completed by IRQ in real firmware. */
    if(++busy_checks<3)return true;
    completed=now;return false;
}
int main(void) {
    for(unsigned i=1;i<=4;++i) {
        scope_demo_cycle();
        assert(sent==i);
        assert(busy_checks==3);
        assert(now-completed>=ALT_CPU_CPU_FREQ/200u);
    }
    assert(retries==1 && drained>4);
    puts("PASS scope firmware: only A, TX queue retry, RX discard, >=5ms delay after TX completion across 4 cycles");
}

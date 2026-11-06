/* Host behavioral model exercises the real C driver. This is not Nios V CPU
 * simulation; generated-HDL connectivity and FPGA fitting are checked separately. */
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "uart_irq.h"
#include "sys/alt_irq.h"
static unsigned enabled=1, in_isr, ier, cfg, tx_used, hw_head, hw_tail;
static uint32_t hw_rx[16];
static unsigned tx_history[1024], tx_count;
static void (*registered_isr)(void *);
static void *registered_context;
alt_irq_context alt_irq_disable_all(void) { unsigned old=enabled; enabled=0; return old; }
void alt_irq_enable_all(alt_irq_context old) { enabled=old; }
int alt_ic_isr_register(unsigned ctrl,unsigned irq,void (*handler)(void*),void *ctx,void *flags) {
    (void)flags; assert(ctrl==0 && irq==0); registered_isr=handler; registered_context=ctx; return 0;
}
uint32_t mock_read(unsigned base,unsigned off) {
    assert(base==0x20000);
    if(off==8) return cfg;
    if(off==12) return (hw_head!=hw_tail ? 2u:0u) | (!tx_used?1u:0u) | (tx_used==16?16u:0u);
    if(off==4) { assert(in_isr && hw_head!=hw_tail); return hw_rx[hw_tail++%16]; }
    assert(0); return 0;
}
void mock_write(unsigned base,unsigned off,uint32_t value) {
    assert(base==0x20000);
    if(off==16) ier=value;
    else if(off==8) cfg=value;
    else { assert(off==0 && tx_used<16 && tx_count<1024); ++tx_used; tx_history[tx_count++]=value; }
}
static unsigned irq_level(void) {return ((ier&1)&&hw_head!=hw_tail)||((ier&2)&&!tx_used);}
static void dispatch(void) {
    unsigned count=0;
    while(enabled && irq_level()) {
        assert(++count<8); /* Detect level IRQ storms. */
        in_isr=1; unsigned old=enabled; enabled=0;
        registered_isr(registered_context);
        enabled=old; in_isr=0;
    }
}
static void receive(unsigned byte) { assert(hw_head-hw_tail<16); hw_rx[hw_head++%16]=byte; }
int main(void) {
    assert(!uart_irq_init() && cfg==0x43 && ier==1 && !irq_level());
    receive('A'); receive(0x142); receive('C');
    assert(!uart_irq_rx_pending()); /* Without IRQ dispatch main sees nothing. */
    dispatch();
    assert(uart_irq_count==1 && uart_rx_count==3 && uart_rx_errors==1);
    assert(uart_irq_getc()=='A' && uart_irq_getc()=='B' && uart_irq_getc()=='C' && uart_irq_getc()==-1);
    assert(!irq_level());
    for(unsigned i=0;i<80;++i) assert(!uart_irq_putc((uint8_t)i));
    while(uart_irq_tx_busy()) {tx_used=0; dispatch();}
    assert(tx_count==80 && ier==1 && !irq_level());
    for(unsigned i=0;i<80;++i) assert(tx_history[i]==i);
    assert(!uart_irq_configure_idle(0x6F) && uart_irq_config()==0x6F && ier==1);
    assert(uart_irq_configure_idle(0x80)==-1);
    receive('Q');
    assert(uart_irq_configure_idle(0x43)==-1 && cfg==0x6F);
    dispatch();
    assert(uart_irq_configure_idle(0x43)==-1 && cfg==0x6F);
    assert(uart_irq_getc()=='Q');
    assert(!uart_irq_putc('!'));
    assert(uart_irq_configure_idle(0x43)==-1 && cfg==0x6F);
    tx_used=0; dispatch();
    assert(!uart_irq_configure_idle(0x43) && cfg==0x43);
    /* Ring overflow must drain hardware and account for every dropped byte. */
    for(unsigned i=0;i<300;++i) {receive(i&255); dispatch();}
    assert(uart_rx_dropped==45);
    for(unsigned i=0;i<255;++i) assert(uart_irq_getc()==(int)(i&255));
    assert(uart_irq_getc()==-1 && !irq_level());
    puts("PASS: real ISR registration, RX only in ISR, byte/error order, TX bursts, idle IRQ masking, ring overflow");
}

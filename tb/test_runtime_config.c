/* Test real shell parser, Terminal-2 line dispatch and deferred config service
 * with a host model of IRQ queues/time. Does not execute a Nios CPU. */
#include <assert.h>
#include <stdio.h>
#include <string.h>
#define UART_WAIT_IRQ() ((void)0)
#define main firmware_main
#include "main.c"
#undef main
uint64_t test_mtime;
volatile uint32_t uart_irq_count, uart_rx_count, uart_tx_count;
volatile uint32_t uart_rx_dropped, uart_rx_errors, uart_rx_overruns;
static uint8_t current_config=0x43;
static bool simulated_busy;
static char serial_log[4096], jtag_log[4096];
static unsigned serial_length,jtag_length;
uint32_t mock_read(unsigned base,unsigned off) { (void)base;return off==4 ? 0xFFFF0000u : 0; }
void mock_write(unsigned base,unsigned off,uint32_t value) {
    (void)off;
    if(base==JTAG_UART_0_BASE) { assert(jtag_length+1<sizeof(jtag_log));jtag_log[jtag_length++]=(char)value; jtag_log[jtag_length]=0; }
}
alt_irq_context alt_irq_disable_all(void) {return 0;}
void alt_irq_enable_all(alt_irq_context saved) {(void)saved;}
int uart_irq_init(void) {return 0;}
int uart_irq_getc(void) {return -1;}
bool uart_irq_rx_pending(void) {return false;}
bool uart_irq_tx_busy(void) {return simulated_busy;}
uint8_t uart_irq_config(void) {return current_config;}
int uart_irq_configure_idle(uint8_t config) {if(simulated_busy)return -1;current_config=config;return 0;}
int uart_irq_putc(uint8_t byte) {assert(serial_length+1<sizeof(serial_log));serial_log[serial_length++]=byte;serial_log[serial_length]=0;return 0;}
int main(void) {
    assert(config_command("config 19200 8E2",false));
    assert(config_pending && current_config==0x43);
    config_service();assert(current_config==0x43);
    test_mtime=ALT_CPU_CPU_FREQ/5u;
    config_service();assert(current_config==0x6F && !config_pending);
    assert(strstr(jtag_log,"APPLIED 19200 8E2"));
    const char *command="@config 4800 7O2\r\n";
    for(const char *p=command;*p;p++)handle_pc_rx_char(*p);
    assert(config_pending && strstr(serial_log,"SWITCH 4800 7O2"));
    simulated_busy=true;test_mtime+=ALT_CPU_CPU_FREQ/4;
    config_service();assert(current_config==0x6F);
    simulated_busy=false;++uart_rx_count;
    config_service();assert(current_config==0x6F); /* RX resets quiet interval. */
    test_mtime+=ALT_CPU_CPU_FREQ/20;
    config_service();assert(current_config==0x3E && !config_pending);
    assert(config_command("baud 9600",false));
    simulated_busy=true;test_mtime+=3ull*ALT_CPU_CPU_FREQ;
    config_service();assert(current_config==0x3E && !config_pending && strstr(jtag_log,"TIMEOUT"));
    simulated_busy=false;
    assert(config_command("config 2400 5N1",true));assert(!config_pending && current_config==0x3E);
    assert(config_command("config 115200 8N1",false));assert(!config_pending);
    assert(config_command("config",true));assert(strstr(serial_log,"CONFIG 4800 7O2"));
    puts("PASS real shell: T1/T2 dispatch, CRLF, old-profile ACK, TX drain, RX quiet, apply, timeout and validation");
}

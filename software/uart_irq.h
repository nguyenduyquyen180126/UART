#ifndef UART_IRQ_H
#define UART_IRQ_H
#include <stdint.h>
#include <stdbool.h>
int uart_irq_init(void);
uint8_t uart_irq_config(void);
/* Caller must coordinate peer silence and allow an RX frame to finish. */
int uart_irq_configure_idle(uint8_t config);
int uart_irq_getc(void);
bool uart_irq_rx_pending(void);
int uart_irq_putc(uint8_t byte);
bool uart_irq_tx_busy(void);
extern volatile uint32_t uart_irq_count, uart_rx_count, uart_tx_count;
extern volatile uint32_t uart_rx_dropped, uart_rx_errors, uart_rx_overruns;
#endif

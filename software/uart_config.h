#ifndef UART_CONFIG_H
#define UART_CONFIG_H
#include <stdint.h>
/* 0 = not a config command, 1 = set, 2 = query, -1 = invalid. */
int uart_config_parse(const char *line, uint8_t current, uint8_t *result);
void uart_config_format(uint8_t config, char *output); /* output >= 16 bytes */
#endif

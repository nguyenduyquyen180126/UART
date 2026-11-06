#include "uart_config.h"
#include <string.h>
#include <stdio.h>
int uart_config_parse(const char *line, uint8_t current, uint8_t *result) {
    while (*line == ' ' || *line == '\t') ++line;
    int is_config = !strncmp(line, "config", 6) && (!line[6] || line[6]==' ' || line[6]=='\t');
    int is_baud = !strncmp(line, "baud", 4) && (!line[4] || line[4]==' ' || line[4]=='\t');
    if (!is_config && !is_baud) return 0;
    char copy[80], *tokens[4];
    unsigned count = 0;
    if (strlen(line) >= sizeof(copy)) return -1;
    strcpy(copy, line);
    char *p = copy;
    while (*p) {
        while (*p == ' ' || *p == '\t') ++p;
        if (!*p) break;
        if (count == 4) return -1;
        tokens[count++] = p;
        while (*p && *p != ' ' && *p != '\t') ++p;
        if (*p) *p++ = 0;
    }
    if (!count || (strcmp(tokens[0], "config") && strcmp(tokens[0], "baud"))) return 0;
    if (count == 1) { *result = current; return 2; }
    int baud_only = !strcmp(tokens[0], "baud");
    if (count != (baud_only ? 2u : 3u)) return -1;
    const char *rates[] = {"2400", "4800", "9600", "19200"};
    unsigned rate;
    for (rate = 0; rate < 4; ++rate) if (!strcmp(tokens[1], rates[rate])) break;
    if (rate == 4) return -1;
    unsigned fields = current & 31u;
    if (!baud_only) {
        const char *f = tokens[2];
        if (strlen(f) != 3 || f[0] < '5' || f[0] > '8' || (f[2] != '1' && f[2] != '2')) return -1;
        char parity = f[1];
        if (parity >= 'a' && parity <= 'z') parity -= 'a' - 'A';
        if (parity != 'N' && parity != 'E' && parity != 'O') return -1;
        fields = (unsigned)(f[0]-'5') | (f[2]=='2' ? 4u : 0u) |
                 (parity=='N' ? 0u : 8u) | (parity=='O' ? 16u : 0u);
    }
    *result = (uint8_t)((rate << 5) | fields);
    return 1;
}
void uart_config_format(uint8_t config, char *output) {
    const unsigned rates[] = {2400,4800,9600,19200};
    char parity = !(config & 8u) ? 'N' : (config & 16u) ? 'O' : 'E';
    sprintf(output, "%u %u%c%u", rates[(config>>5)&3u], 5u+(config&3u), parity, 1u+((config>>2)&1u));
}

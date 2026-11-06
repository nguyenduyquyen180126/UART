#ifndef DEMO_CLOCK_H
#define DEMO_CLOCK_H
#include <stdbool.h>
typedef struct {
    unsigned hold_ticks, partial_ticks, seconds;
    bool changed;
} demo_clock_t;
static inline void demo_clock_receive(volatile demo_clock_t *clock) {
    clock->hold_ticks = 100;
}
/* One tick = 10ms; preserve the unfinished second throughout UART service. */
static inline void demo_clock_tick(volatile demo_clock_t *clock, bool uart_busy) {
    if (clock->hold_ticks) --clock->hold_ticks;
    else if (!uart_busy && ++clock->partial_ticks == 100) {
        clock->partial_ticks = 0;
        clock->seconds = clock->seconds == 60 ? 0 : clock->seconds + 1;
        clock->changed = true;
    }
}
#endif

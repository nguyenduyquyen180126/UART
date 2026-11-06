#include <assert.h>
#include <stdio.h>
#include "demo_clock.h"
int main(void) {
    demo_clock_t clock = {0,0,0,false};
    for (unsigned i=0;i<3745;++i) demo_clock_tick(&clock,false);
    assert(clock.seconds==37 && clock.partial_ticks==45);
    demo_clock_receive(&clock);
    for (unsigned i=0;i<100;++i) demo_clock_tick(&clock,false);
    assert(clock.seconds==37 && clock.partial_ticks==45);
    for (unsigned i=0;i<200;++i) demo_clock_tick(&clock,true);
    assert(clock.seconds==37 && clock.partial_ticks==45);
    for (unsigned i=0;i<55;++i) demo_clock_tick(&clock,false);
    assert(clock.seconds==38 && clock.partial_ticks==0);
    for (unsigned i=0;i<2200;++i) demo_clock_tick(&clock,false);
    assert(clock.seconds==60);
    for (unsigned i=0;i<100;++i) demo_clock_tick(&clock,false);
    assert(clock.seconds==0);
    puts("PASS: 37.45s pauses across RX/echo then resumes at 38s; inclusive 60 rolls over to 00");
}

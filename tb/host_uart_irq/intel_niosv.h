#ifndef MOCK_NIOSV_H
#define MOCK_NIOSV_H
#include <stdint.h>
extern uint64_t test_mtime;
static inline uint64_t alt_niosv_mtime_get(void) { return test_mtime; }
#endif

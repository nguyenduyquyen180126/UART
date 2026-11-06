#include <stdint.h>
uint32_t mock_read(unsigned base, unsigned offset);
void mock_write(unsigned base, unsigned offset, uint32_t value);
#define IORD_32DIRECT(base, offset) mock_read(base, offset)
#define IOWR_32DIRECT(base, offset, value) mock_write(base, offset, value)

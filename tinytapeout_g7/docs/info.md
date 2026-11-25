# HUST APB UART

Tiny Tapeout wrapper for the existing SPI-to-APB UART. `clk` is the only design clock (25 MHz); SPI and UART inputs are sampled/synchronized into this clock domain. The SPI interface uses the existing 56-bit command protocol implemented by `spi2apb_apb_master`.

## Pin mapping

- `ui_in[0]`: UART RX
- `ui_in[1]`: UART CTS_N
- `ui_in[2]`: SPI CS_N
- `ui_in[3]`: SPI SCLK
- `ui_in[4]`: SPI MOSI
- `uo_out[0]`: UART TX
- `uo_out[1]`: UART RTS_N
- `uo_out[2]`: SPI MISO
- `uo_out[3]`: UART TX_DONE
- `uo_out[4]`: UART RX_DONE
- `uo_out[5]`: UART PARITY_ERR
- `uo_out[6]`: UART IRQ
- `uo_out[7]`: reserved scan output, tied low
- `uio_*`: unused, all outputs disabled

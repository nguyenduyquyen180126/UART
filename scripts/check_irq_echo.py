#!/usr/bin/env python3
"""Hardware echo check for irq_demo; close picocom/other serial apps first.
The echo check alone cannot prove IRQ use or the HEX pause: inspect JTAG ISR
counts and HEX3:HEX2 too. Requires pyserial on the PC, never runs during build.
"""
import argparse
import time
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('port',help='/dev/serial/by-id/... or /dev/ttyUSB0')
a=p.parse_args()
try:
    import serial
except ImportError:
    p.exit(2,'Install pyserial in your Python environment first.\n')
with serial.Serial(a.port,9600,timeout=2,write_timeout=2,rtscts=False,dsrdtr=False) as port:
    port.reset_input_buffer()
    for payload in [b'A',b'xyz',bytes(range(32,127))]:
        port.write(payload)
        received=bytearray()
        deadline=time.monotonic()+5
        while len(received)<len(payload) and time.monotonic()<deadline:
            received.extend(port.read(len(payload)-len(received)))
        if bytes(received)!=payload:
            p.exit(1,f'FAIL sent={payload!r} received={bytes(received)!r}\n')
        print(f'PASS exact echo: {len(payload)} bytes')
        time.sleep(2)
print('Echo passed. Verify JTAG ISR counter increases and HEX3:HEX2 resumes without reset.')

#!/usr/bin/env python3
"""Test the loaded irq_demo over USB-UART and correlate RX with CPU JTAG logs.
Close other serial/JTAG terminals first. Does not program or reset the FPGA.
"""
import argparse
import os
from pathlib import Path
import re
import subprocess
import time
import serial

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('port')
parser.add_argument('--wrap-check', action='store_true', help='Also wait for and verify the 60-to-00 rollover')
parser.add_argument('--cable', default='USB-Blaster [3-11]')
parser.add_argument('--log', default='build/logs/hardware-demo-jtag.log')
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
log_path = root / args.log
log_path.parent.mkdir(parents=True, exist_ok=True)
terminal = Path(os.environ.get('ALTERA_DIR', '/home/vietanh/altera_lite/24.1std')) / 'quartus/bin/juart-terminal'
record = re.compile(r'RX=([0-9A-F]{8}) seconds=([0-9A-F]{8}) ISR=([0-9A-F]{8}) ticks=([0-9A-F]{8})')

def records():
    return [tuple(int(v, 16) for v in item) for item in record.findall(log_path.read_text(errors='replace'))]

with log_path.open('w') as output:
    process = subprocess.Popen(['stdbuf', '-oL', '-eL', str(terminal), '-c', args.cable, '-o', '110' if args.wrap_check else '35'], stdin=subprocess.PIPE,
                               stdout=output, stderr=subprocess.STDOUT)
    try:
        time.sleep(1)
        with serial.Serial(args.port, 9600, timeout=0.1, write_timeout=2,
                           rtscts=False, dsrdtr=False, exclusive=True) as port:
            port.reset_input_buffer()
            def echo(payload):
                port.write(payload)
                port.flush()
                data = bytearray()
                deadline = time.monotonic() + 5
                while len(data) < len(payload) and time.monotonic() < deadline:
                    data.extend(port.read(len(payload)-len(data)))
                if bytes(data) != payload:
                    raise RuntimeError(f'echo mismatch: sent={payload!r}, got={bytes(data)!r}')
                print(f'PASS exact echo {len(payload)} bytes', flush=True)
            # Let the counter advance; probe bytes also produce JTAG RX/ISR evidence.
            time.sleep(3)
            startup = port.read(port.in_waiting)
            if startup:
                print(f'Startup data before test payload: {startup.hex()}', flush=True)
            def probe(byte):
                before = len(records())
                echo(bytes([byte]))
                deadline = time.monotonic() + 2
                while time.monotonic() < deadline:
                    fresh = records()[before:]
                    matching = [r for r in fresh if r[0] == byte]
                    if matching:
                        return matching[-1]
                    time.sleep(0.05)
                raise RuntimeError('UART echoed but matching JTAG RX/ISR record missing')
            first = probe(ord('A'))
            time.sleep(0.2)
            held = probe(ord('B'))
            if first[1] != held[1] or held[2] <= first[2] or held[3] <= first[3]:
                raise RuntimeError(f'pause/ISR/timer check failed: {first}, {held}')
            print(f'PASS counter holds at {held[1]:02d}; ISR and timer continue', flush=True)
            time.sleep(2.2)
            resumed = probe(ord('C'))
            delta = (resumed[1]-held[1]) % 61
            if delta not in (1, 2) or resumed[2] <= held[2]:
                raise RuntimeError(f'counter did not resume from saved value: {held}, {resumed}')
            print(f'PASS counter resumes {held[1]:02d} -> {resumed[1]:02d}', flush=True)
            echo(b'xyz')
            echo(bytes(range(32, 127)))
            time.sleep(0.3)
            echo(bytes(range(256)) * 4)
            if args.wrap_check:
                time.sleep(0.5)
                baseline = probe(ord('D'))
                wait = max(0, 60 - baseline[1])
                print(f'Waiting {wait}s for counter near 60 (current {baseline[1]:02d})', flush=True)
                time.sleep(wait)
                before_wrap = probe(ord('E'))
                time.sleep(3.2)
                after_wrap = probe(ord('F'))
                if not (before_wrap[1] in (59, 60) and after_wrap[1] < before_wrap[1]
                        and 1 <= (after_wrap[1]-before_wrap[1]) % 61 <= 3
                        and after_wrap[3] > before_wrap[3]):
                    raise RuntimeError(f'rollover check failed: {before_wrap}, {after_wrap}')
                print(f'PASS 60-to-00 rollover: {before_wrap[1]:02d} -> {after_wrap[1]:02d}; timer never reset', flush=True)
            print('PASS hardware demo: RX ISR evidence, pause/resume, short/burst/binary echo', flush=True)
    finally:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()

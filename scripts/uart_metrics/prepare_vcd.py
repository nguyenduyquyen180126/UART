"""Strip only testbench hierarchy; retain all DUT signal activity and times."""
import sys
from pathlib import Path
src, dst = map(Path, sys.argv[1:])
with src.open() as r, dst.open('w') as w:
    depth = 0
    for line in r:
        if line.startswith('$scope'):
            depth += 1
            if depth == 1:
                assert 'tb_uart_power' in line, line
                continue
            if depth == 2:
                assert 'dut' in line, line
                line = '$scope module apb_uart $end\n'
        elif line.startswith('$upscope'):
            depth -= 1
            if depth == 0:
                continue
        w.write(line)

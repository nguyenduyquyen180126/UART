#!/usr/bin/env python3
"""Fingerprint all sources that affect generated images, relative to repo root."""
from pathlib import Path
import hashlib
root = Path(__file__).resolve().parent.parent
paths = [root/'apb_uart_hw.tcl']
for folder, patterns in [('rtl', ['*.v']), ('fpga', ['*.v','*.qsys','*.qsf','*.sdc']),
                         ('software', ['*.c','*.h','CMakeLists.txt']),
                         ('scripts', ['build_soc.sh','source_manifest.py','check_soc.py','report_irq_path.tcl'])]:
    for pattern in patterns:
        paths.extend((root/folder).glob(pattern))
for path in sorted(set(paths)):
    print(hashlib.sha256(path.read_bytes()).hexdigest(), path.relative_to(root))

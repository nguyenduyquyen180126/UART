"""Extract reported values without conflating standalone and in-SoC results."""
import hashlib
import json
import re
from pathlib import Path
root = Path(__file__).resolve().parents[2]
out = root / 'build/uart_metrics'
def read(path):
    return path.read_text(errors='replace')
def resources(path, node):
    text = read(path)
    start = text.index('; Fitter Resource Utilization by Entity ')
    for line in text[start:].splitlines():
        fields = [s.strip() for s in line.split(';')[1:-1]]
        if len(fields) >= 17 and fields[0] == node:
            first = lambda n: int(fields[n].split()[0])
            return dict(logic_elements=first(1), dedicated_registers=first(2),
                        memory_bits=first(4), m9k=first(5), dsp_elements=first(6),
                        lut_only_lcs=first(11), register_only_lcs=first(12),
                        lut_register_lcs=first(13), lut_lcs=first(11)+first(13))
    raise ValueError(f'Hierarchy missing: {node}')
def timing(path):
    return [dict(corner=m[0], setup_slack_ns=float(m[1]),
                 reg_reg_equivalent_fmax_mhz=float(m[2]))
            for m in re.findall(r'CORE_SETUP_CORNER=(\S+) SLACK_NS=(\S+) PERIOD_NS=20.000 IMPLIED_REG_REG_FMAX_MHZ=(\S+)', read(path))]
results = dict(device='EP4CE115F29C7', clock_mhz=50, parameter_clk_freq=50000000,
               standalone=resources(out/'output_files/uart_metrics.fit.rpt', '|apb_uart'),
               standalone_core_timing=timing(out/'core_timing.log'), power={})
soc = root/'fpga/output_files/NIOS.fit.rpt'
if soc.exists():
    results['in_soc'] = resources(soc, '|apb_uart:apb_uart_0|')
if (out/'soc_core_timing.log').exists():
    results['in_soc_core_timing'] = timing(out/'soc_core_timing.log')
for scenario in ('idle', 'active', 'idle_gate', 'active_gate'):
    p = out/f'power-{scenario}-25c.summary'
    if p.exists():
        results['power'][scenario] = dict(line.split(' : ', 1) for line in read(p).splitlines() if ' : ' in line)
results['rtl_sha256'] = {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((root/'rtl').glob('*.v'))}
(out/'results.json').write_text(json.dumps(results, indent=2)+'\n')
print(json.dumps(results, indent=2))

#!/usr/bin/env python3
"""Audit source maps, generated RTL IRQ nets, source freshness and board pins."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET
root = Path(__file__).resolve().parent.parent
sys = ET.parse(root/'fpga/system.qsys').getroot()
cpu = sys.find("module[@name='intel_niosv_m_0']")
assert cpu is not None and cpu.get('kind') == 'intel_niosv_m'
connections = sys.findall('connection')
def connected(start, end, kind, param=None, expected=None):
    matches = [c for c in connections if c.get('start')==start and c.get('end')==end and c.get('kind')==kind]
    assert len(matches)==1, (start,end)
    if param:
        p=matches[0].find(f"parameter[@name='{param}']")
        assert p is not None and int(p.get('value'),0)==expected, (start,end,param)
for end, addr in [('apb_uart_0.apb_slave',0x20000),('pio_0.s1',0x10000),
                  ('pio_sw.s1',0x10020),('pio_key.s1',0x10030),
                  ('jtag_uart_0.avalon_jtag_slave',0x10010),('onchip_memory2_0.s1',0),
                  ('pio_hex.s1',0x10040),('intel_niosv_m_0.timer_sw_agent',0x30000)]:
    connected('intel_niosv_m_0.data_manager',end,'avalon','baseAddress',addr)
connected('intel_niosv_m_0.instruction_manager','onchip_memory2_0.s1','avalon','baseAddress',0)
connected('intel_niosv_m_0.platform_irq_rx','apb_uart_0.interrupt_sender','interrupt','irqNumber',0)
synth=root/'fpga/system/synthesis'
verilog=(synth/'system.v').read_text()
for pattern in [r'\.irq\s*\(irq_mapper_receiver0_irq\)',
                r'\.receiver0_irq\s*\(irq_mapper_receiver0_irq\)',
                r'\.sender_irq\s*\(intel_niosv_m_0_platform_irq_rx_irq\)',
                r'\.platform_irq_rx_irq\s*\(intel_niosv_m_0_platform_irq_rx_irq\)']:
    assert re.search(pattern,verilog),pattern
assert 'sender_irq[0] = receiver0_irq' in (synth/'submodules/system_irq_mapper.sv').read_text()
assert re.search(r'\.irq_plat_vec\s*\(platform_irq_rx_irq\)',
                 (synth/'submodules/system_intel_niosv_m_0.v').read_text())
header=(root/'software/bsp/system.h').read_text()
for name,value in [('APB_UART_0_IRQ','0'),('APB_UART_0_IRQ_INTERRUPT_CONTROLLER_ID','0'),
                   ('ALT_CPU_HAS_CSR_SUPPORT','1')]:
    assert re.search(rf'^#define {name}\s+{value}\s*$',header,re.M),name
# Quartus copies component RTL during generation. Never silently use old copies.
for source in (root/'rtl').glob('*.v'):
    generated=synth/'submodules'/source.name
    if generated.exists(): assert source.read_bytes()==generated.read_bytes(),source
qsf=(root/'fpga/NIOS.qsf').read_text()
pins=re.findall(r'set_location_assignment (PIN_\w+) -to (\S+)',qsf)
assert len(pins)==len({pin for pin,port in pins}), 'A physical pin is assigned twice'
assert len(pins)==len({port for pin,port in pins}), 'A port has multiple physical pin assignments'
by_port={port:pin for pin,port in pins}
assert by_port['UART_RXD']=='PIN_AB22' and by_port['UART_TXD']=='PIN_AC15'
for digit,locations in [(2,'AA25 AA26 Y25 W26 Y26 W27 W28'),(3,'V21 U21 AB20 AA21 AD24 AF23 Y19')]:
    for i,pin in enumerate(locations.split()):
        assert by_port[f'HEX{digit}[{i}]']=='PIN_'+pin
        voltage='3.3-V LVTTL' if digit==3 and i>=2 else '2.5 V'
        assert f'-name IO_STANDARD "{voltage}" -to HEX{digit}[{i}]' in qsf
print('PASS: address map, CPU IRQ 0 end-to-end generated RTL, CSR support, current RTL copies, GPIO/HEX pins and I/O standards')

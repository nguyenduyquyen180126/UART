#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generate a slide-optimized, ultra-clear draw.io XML diagram, SVG vector, and JSON wrapper
representing the Nios V/c (AXI4-Lite) -> Merlin Interconnect -> APB UART architecture.
Completely aligned, pristine bus trunk routing, zero crossing lines, presentation-ready.
"""

import html
import json
from pathlib import Path
import xml.etree.ElementTree as ET

DOC_DIR = Path(__file__).resolve().parent
XML_OUT = DOC_DIR / "schematic_cpu_apb_uart.xml"
DRAWIO_OUT = DOC_DIR / "schematic_cpu_apb_uart.drawio"
SVG_OUT = DOC_DIR / "schematic_cpu_apb_uart.svg"
JSON_OUT = DOC_DIR / "schematic_cpu_apb_uart.json"

WIDTH = 2160
HEIGHT = 1260

nodes = []
edges = []

def add_node(id, x, y, w, h, label, fill='#ffffff', stroke='#334155', stroke_w=2,
             font_size=13, font_color='#0f172a', font_weight='normal', align='center',
             dashed=False, rounded=1, z_index=1):
    nodes.append({
        'id': id, 'x': x, 'y': y, 'w': w, 'h': h,
        'label': label, 'fill': fill, 'stroke': stroke, 'stroke_w': stroke_w,
        'font_size': font_size, 'font_color': font_color, 'font_weight': font_weight,
        'align': align, 'dashed': dashed, 'rounded': rounded, 'z_index': z_index
    })

def add_edge(id, src_id, dst_id, points, label='', color='#2563eb', stroke_w=2,
             both=False, dashed=False, font_size=11, label_bg='#ffffff', label_pos=None):
    edges.append({
        'id': id, 'src': src_id, 'dst': dst_id, 'points': points,
        'label': label, 'color': color, 'stroke_w': stroke_w,
        'both': both, 'dashed': dashed, 'font_size': font_size, 'label_bg': label_bg,
        'label_pos': label_pos
    })

# =============================================================
# 1. TOP HEADER BANNER
# =============================================================
add_node('banner_bg', 30, 20, 2100, 85, '', fill='#0f172a', stroke='#1e293b', stroke_w=2, rounded=1, z_index=0)
add_node('banner_title', 40, 28, 2080, 40,
         '<b style="font-size:24px; color:#38bdf8;">KIẾN TRÚC KẾT NỐI HỆ THỐNG: NIOS V/C (AXI4-LITE) → INTERCONNECT MERLIN → APB UART</b>',
         fill='none', stroke='none', font_size=24, font_color='#38bdf8', font_weight='bold', z_index=2)
add_node('banner_sub', 40, 68, 2080, 28,
         'Khảo sát trực tiếp từ HDL thực tế (system.v) &amp; Platform Designer (system.qsys) | Bus AXI4-Lite, APB 81 dây logic, Register File &amp; TX/RX FIFO',
         fill='none', stroke='none', font_size=14, font_color='#94a3b8', z_index=2)

# =============================================================
# 2. MAIN CONTAINERS
# =============================================================
# FPGA Boundary
add_node('fpga_box', 30, 120, 1630, 895, '', fill='#f8fafc', stroke='#475569', stroke_w=2.5, dashed=True, rounded=1, z_index=0)
add_node('fpga_header', 40, 130, 1610, 36,
         '<b style="font-size:16px; color:#1e293b;">CHIP FPGA CYCLONE IV E (EP4CE115F29C7) — HỆ THỐNG SOC QUARTUS (system.qsys / NIOS.v)</b>',
         fill='#e2e8f0', stroke='#94a3b8', stroke_w=1, font_size=15, font_color='#1e293b', font_weight='bold', z_index=1)

# External Environment Boundary
add_node('ext_box', 1690, 120, 440, 895, '', fill='#f0fdfa', stroke='#0d9488', stroke_w=2.5, dashed=True, rounded=1, z_index=0)
add_node('ext_header', 1700, 130, 420, 36,
         '<b style="font-size:16px; color:#0f766e;">MÔI TRƯỜNG NGOÀI (EXTERNAL BOARDS &amp; PC)</b>',
         fill='#ccfbf1', stroke='#5eead4', stroke_w=1, font_size=15, font_color='#0f766e', font_weight='bold', z_index=1)

# =============================================================
# 3. CPU SUBSYSTEM (intel_niosv_c_0)
# =============================================================
add_node('cpu_box', 50, 180, 270, 650, '', fill='#eff6ff', stroke='#3b82f6', stroke_w=2, rounded=1, z_index=1)
add_node('cpu_title', 50, 180, 270, 50,
         '<b style="font-size:16px; color:#1d4ed8;">CPU NIOS V/c</b><br/><span style="font-size:12px; color:#3b82f6;">RV32IM Core (intel_niosv_c_0)</span>',
         fill='#dbeafe', stroke='#3b82f6', stroke_w=1, font_size=15, font_color='#1e3a8a', z_index=2)

add_node('cpu_param_box', 60, 238, 250, 65,
         '<b style="color:#b91c1c; font-size:12px;">ĐẶC TẢ GIAO DIỆN HDL:</b><br/>'
         '<span style="font-size:11px; color:#334155;">enableAvalonInterface = <b>false</b><br/>'
         'AXI_VERSION = <b>AXI4Lite</b></span>',
         fill='#fee2e2', stroke='#ef4444', stroke_w=1, font_size=11, font_color='#7f1d1d', z_index=2)

add_node('cpu_im_box', 60, 312, 250, 75,
         '<b style="color:#1e40af; font-size:13px;">instruction_manager</b><br/>'
         '<span style="font-size:11px; color:#475569;">Bus lấy lệnh (AXI4-Lite)<br/>'
         'Truy cập mã lệnh từ On-Chip RAM</span>',
         fill='#ffffff', stroke='#60a5fa', stroke_w=1.5, font_size=11, font_color='#1e40af', z_index=2)

add_node('cpu_dm_box', 60, 395, 250, 425,
         '<b style="color:#1e40af; font-size:14px;">data_manager</b><br/>'
         '<span style="font-size:11px; color:#2563eb;"><b>Master AXI4-Lite (MMIO &amp; Data)</b></span><br/><hr style="margin:4px 0; border:0; border-top:1px solid #bfdbfe;"/>'
         '<div style="text-align:left; font-size:11px; color:#1e293b; line-height:1.45; padding-left:4px;">'
         '<b>• Kênh AW (Địa chỉ ghi):</b><br/>'
         '&nbsp;&nbsp;awaddr[31:0], awvalid, awready<br/>'
         '<b>• Kênh W (Dữ liệu ghi):</b><br/>'
         '&nbsp;&nbsp;wdata[31:0], wstrb[3:0], wvalid, wready<br/>'
         '<b>• Kênh B (Phản hồi ghi):</b><br/>'
         '&nbsp;&nbsp;bresp[1:0], bvalid, bready<br/>'
         '<b>• Kênh AR (Địa chỉ đọc):</b><br/>'
         '&nbsp;&nbsp;araddr[31:0], arvalid, arready<br/>'
         '<b>• Kênh R (Dữ liệu đọc):</b><br/>'
         '&nbsp;&nbsp;rdata[31:0], rresp[1:0], rvalid, rready'
         '</div>',
         fill='#ffffff', stroke='#2563eb', stroke_w=2, font_size=11, font_color='#1e293b', align='left', z_index=2)

# =============================================================
# 4. PLATFORM DESIGNER INTERCONNECT (mm_interconnect_0)
# =============================================================
add_node('merlin_box', 390, 180, 410, 650, '', fill='#fefce8', stroke='#ca8a04', stroke_w=2, rounded=1, z_index=1)
add_node('merlin_title', 390, 180, 410, 50,
         '<b style="font-size:16px; color:#854d0e;">INTERCONNECT MERLIN (mm_interconnect_0)</b><br/>'
         '<span style="font-size:12px; color:#a16207;">Hạ tầng chuyển đổi giao thức &amp; định tuyến Platform Designer</span>',
         fill='#fef08a', stroke='#ca8a04', stroke_w=1, font_size=15, font_color='#854d0e', z_index=2)

# Sub-block 1: AXI Master NI
add_node('merlin_ni', 405, 238, 380, 85,
         '<b style="font-size:13px; color:#854d0e;">1. AXI Master Network Interface (NI)</b><br/>'
         '<span style="font-size:11px; color:#713f12;">Instance: <i>intel_niosv_c_0_data_manager_agent</i><br/>'
         'Module: <b>altera_merlin_axi_master_ni</b> (AXI_VERSION="AXI4Lite")<br/>'
         'Chức năng: Chuyển 5 kênh AXI4-Lite ↔ Gói tin streaming Merlin</span>',
         fill='#ffffff', stroke='#eab308', stroke_w=1.5, font_size=11, font_color='#713f12', z_index=2)

# Sub-block 2: Router & Switch Fabric
add_node('merlin_router', 405, 332, 380, 140,
         '<b style="font-size:13px; color:#854d0e;">2. Merlin Router &amp; Crossbar Fabric</b><br/>'
         '<span style="font-size:11px; color:#713f12;">Gói tin Command/Response Packet (<b>106-bit</b> data + routing)<br/>'
         'Bản đồ giải mã địa chỉ hệ thống:</span><br/>'
         '<div style="text-align:left; font-size:11px; color:#1e293b; line-height:1.35; padding-left:12px;">'
         '• <b>0x0000_0000 .. 0x0000_FFFF:</b> On-chip RAM (64 KiB)<br/>'
         '• <b>0x0001_0000 .. 0x0001_003F:</b> PIO Out 8 / SW 8 / KEY 1<br/>'
         '• <b>0x0001_0010 .. 0x0001_0017:</b> JTAG UART IP<br/>'
         '• <b>0x0002_0000 .. 0x0002_0FFF:</b> <b>APB UART (Span 4 KiB)</b>'
         '</div>',
         fill='#ffffff', stroke='#eab308', stroke_w=1.5, font_size=11, font_color='#713f12', align='left', z_index=2)

# Sub-block 3: APB Slave Agent
add_node('merlin_apb_agent', 405, 482, 380, 160,
         '<b style="font-size:13px; color:#6b21a8;">3. APB Slave Agent (Đóng vai trò APB Master)</b><br/>'
         '<span style="font-size:11px; color:#581c87;">Instance: <i>apb_uart_0_apb_slave_agent</i><br/>'
         'Module: <b>altera_merlin_apb_slave_agent</b></span><br/>'
         '<div style="text-align:left; font-size:11px; color:#1e293b; line-height:1.4; padding-left:8px;">'
         '• <b>Máy trạng thái FSM:</b> IDLE → SET_UP → ACCESS → SEND_RESPONSE<br/>'
         '• <b>Phát pha SETUP:</b> PSEL=1, PENABLE=0, giữ PADDR, PWDATA<br/>'
         '• <b>Phát pha ACCESS:</b> PENABLE=1, chờ PREADY từ Slave<br/>'
         '• <b>Bảo vệ FIFO:</b> Chốt response, không pop đúp khi mạng bận'
         '</div>',
         fill='#faf5ff', stroke='#9333ea', stroke_w=2, font_size=11, font_color='#581c87', align='left', z_index=2)

# Sub-block 4: APB Translator
add_node('merlin_apb_trans', 405, 652, 380, 85,
         '<b style="font-size:13px; color:#6b21a8;">4. APB Translator (Pass-through &amp; Width Adapter)</b><br/>'
         '<span style="font-size:11px; color:#581c87;">Instance: <i>apb_uart_0_apb_slave_translator</i><br/>'
         'Module: <b>altera_merlin_apb_translator</b> (ADDR=12, DATA=32, PSLVERR=1)<br/>'
         'Đưa bó 81 tín hiệu APB trực tiếp ra cổng IP UART</span>',
         fill='#faf5ff', stroke='#a855f7', stroke_w=1.5, font_size=11, font_color='#581c87', z_index=2)

add_node('merlin_avalon_agents', 405, 747, 380, 73,
         '<span style="font-size:11px; color:#166534;"><b>Avalon-MM Slave Agents:</b><br/>'
         'Chuyển đổi gói tin Merlin ↔ Bus Avalon-MM giao tiếp với On-chip RAM, JTAG UART và PIO</span>',
         fill='#f0fdf4', stroke='#22c55e', stroke_w=1.5, font_size=11, font_color='#166534', z_index=2)

# =============================================================
# 5. OTHER PERIPHERALS (RAM, JTAG UART, PIO) - TOP ROW
# =============================================================
# RAM (64 KiB)
add_node('ram_box', 890, 180, 215, 110,
         '<b style="font-size:13px; color:#1e293b;">On-chip RAM (64 KiB)</b><br/>'
         '<span style="font-size:11px; color:#475569;">Instance: <i>onchip_memory2_0</i><br/>'
         'Bus: Avalon-MM Target<br/>'
         'Địa chỉ: 0x00000 .. 0x0FFFF</span><br/>'
         '<span style="font-size:10px; color:#b91c1c;">(HDL/BSP: Có thật; Qsys: disabled)</span>',
         fill='#f1f5f9', stroke='#64748b', stroke_w=1.5, font_size=11, font_color='#1e293b', z_index=2)

# JTAG UART
add_node('jtag_box', 1135, 180, 215, 110,
         '<b style="font-size:13px; color:#166534;">jtag_uart_0 (Console)</b><br/>'
         '<span style="font-size:11px; color:#14532d;">Instance: <i>jtag_uart_0</i><br/>'
         'Bus: Avalon-MM Target<br/>'
         'Địa chỉ: 0x00010010 .. 0x00010017<br/>'
         'Nối TAP Controller → USB-Blaster</span>',
         fill='#f0fdf4', stroke='#16a34a', stroke_w=1.5, font_size=11, font_color='#14532d', z_index=2)

# PIO Controller
add_node('pio_box', 1380, 180, 240, 110,
         '<b style="font-size:13px; color:#166534;">PIO Controller (8-bit)</b><br/>'
         '<span style="font-size:11px; color:#14532d;">Instance: <i>pio_0</i> (Avalon-MM)<br/>'
         '• 0x10000: Out 8-bit → LEDG &amp; HEX<br/>'
         '• 0x10020: In 8-bit ← SW[7:0]<br/>'
         '• 0x10030: In 1-bit ← KEY[1]</span>',
         fill='#f0fdf4', stroke='#16a34a', stroke_w=1.5, font_size=11, font_color='#14532d', z_index=2)

# =============================================================
# 6. CUSTOM APB UART IP (apb_uart_0) - Extra Wide Corridor!
# =============================================================
add_node('uart_ip_box', 910, 320, 720, 510, '', fill='#fff7ed', stroke='#ea580c', stroke_w=2, rounded=1, z_index=1)
add_node('uart_ip_title', 910, 320, 720, 36,
         '<b style="font-size:15px; color:#9a3412;">CUSTOM IP: apb_uart_0 (Base: 0x0002_0000, Span: 4 KiB)</b>',
         fill='#ffedd5', stroke='#ea580c', stroke_w=1, font_size=15, font_color='#9a3412', z_index=2)

# APB Slave Frontend (u_apb_slave)
add_node('u_apb_slave', 925, 365, 235, 235,
         '<b style="font-size:13px; color:#c2410c;">u_apb_slave (apb_slave.v)</b><br/>'
         '<span style="font-size:11px; color:#9a3412;"><b>Mạch tổ hợp thuần túy (Không FSM)</b></span><br/><hr style="margin:4px 0; border:0; border-top:1px solid #fed7aa;"/>'
         '<div style="text-align:left; font-size:11px; color:#1e293b; line-height:1.45; padding-left:4px;">'
         '• <b>pready = psel &amp; penable</b><br/>'
         '&nbsp;&nbsp;(Hoàn tất ngay, không wait-state)<br/>'
         '• <b>addr_valid:</b><br/>'
         '&nbsp;&nbsp;(paddr &lt;= 0x10) &amp;&amp; (paddr[1:0]==0)<br/>'
         '• <b>reg_pwrite =</b><br/>'
         '&nbsp;&nbsp;psel &amp; penable &amp; addr_valid &amp; pwrite<br/>'
         '• <b>reg_pread =</b><br/>'
         '&nbsp;&nbsp;psel &amp; penable &amp; addr_valid &amp; ~pwrite<br/>'
         '• <b>pslverr =</b><br/>'
         '&nbsp;&nbsp;psel &amp; penable &amp; (!valid | err)'
         '</div>',
         fill='#ffffff', stroke='#f97316', stroke_w=2, font_size=11, font_color='#1e293b', align='left', z_index=2)

# Register File (u_uart_regs)
add_node('u_uart_regs', 925, 625, 235, 190,
         '<b style="font-size:13px; color:#c2410c;">u_uart_regs (uart_regs.v)</b><br/>'
         '<span style="font-size:11px; color:#9a3412;"><b>Register File nội bộ (Offset 0x00..0x10)</b></span><br/><hr style="margin:4px 0; border:0; border-top:1px solid #fed7aa;"/>'
         '<div style="text-align:left; font-size:11px; color:#1e293b; line-height:1.4; padding-left:4px;">'
         '• <b>0x000 TX:</b> Ghi byte → Push TX FIFO<br/>'
         '• <b>0x004 RX:</b> Đọc byte &amp; Pop RX FIFO<br/>'
         '• <b>0x008 CFG:</b> 9600-8N1 (0x43), Parity E/O<br/>'
         '• <b>0x00C STT:</b> [0] TX Done, [1] RX Ready,<br/>'
         '&nbsp;&nbsp;[4] TX Full, [5] RX Full, [3] Overrun<br/>'
         '• <b>0x010 IER:</b> Cho phép ngắt RX, TX, OVR'
         '</div>',
         fill='#ffffff', stroke='#f97316', stroke_w=2, font_size=11, font_color='#1e293b', align='left', z_index=2)

# TX Path Box (Left-to-Right: FIFO -> Core -> Pin)
add_node('tx_path_box', 1185, 365, 430, 165, '', fill='#ffffff', stroke='#3b82f6', stroke_w=1.5, rounded=1, z_index=2)
add_node('tx_path_title', 1185, 365, 430, 26,
         '<b style="font-size:12px; color:#1d4ed8;">KHỐI PHÁT DỮ LIỆU (TX DATA PATH)</b>',
         fill='#dbeafe', stroke='#93c5fd', stroke_w=1, font_size=12, font_color='#1d4ed8', z_index=3)

add_node('u_tx_fifo', 1195, 398, 195, 122,
         '<b style="font-size:12px; color:#1e40af;">u_tx_fifo</b><br/>'
         '<span style="font-size:11px; color:#334155;">sync_fifo (16 × 8-bit)<br/><hr style="margin:3px 0;"/>'
         'wr_en, wr_data[7:0]<br/>'
         'rd_en (pop khi core nạp)<br/>'
         'empty, full cờ STT</span>',
         fill='#eff6ff', stroke='#60a5fa', stroke_w=1.5, font_size=11, font_color='#1e40af', z_index=3)

add_node('u_tx_uart', 1410, 398, 195, 122,
         '<b style="font-size:12px; color:#c2410c;">u_tx_uart Core</b><br/>'
         '<span style="font-size:11px; color:#334155;">tx_controller, baud_gen<br/>'
         'tx_piso, tx_parity<br/><hr style="margin:3px 0;"/>'
         '<b style="color:#ea580c;">PIN_AC15 (UART_TXD)</b></span>',
         fill='#fff7ed', stroke='#f97316', stroke_w=1.5, font_size=11, font_color='#c2410c', z_index=3)

# RX Path Box (Right-to-Left: Pin -> Core -> FIFO -> Regs!)
add_node('rx_path_box', 1185, 545, 430, 165, '', fill='#ffffff', stroke='#3b82f6', stroke_w=1.5, rounded=1, z_index=2)
add_node('rx_path_title', 1185, 545, 430, 26,
         '<b style="font-size:12px; color:#1d4ed8;">KHỐI THU DỮ LIỆU (RX DATA PATH)</b>',
         fill='#dbeafe', stroke='#93c5fd', stroke_w=1, font_size=12, font_color='#1d4ed8', z_index=3)

# On the left: u_rx_fifo (feeds u_uart_regs directly!)
add_node('u_rx_fifo', 1195, 578, 195, 122,
         '<b style="font-size:12px; color:#1e40af;">u_rx_fifo</b><br/>'
         '<span style="font-size:11px; color:#334155;">sync_fifo (16 × 9-bit)<br/><hr style="margin:3px 0;"/>'
         '8-bit data + 1-bit err<br/>'
         'rd_en (pop ở cạnh clk)<br/>'
         'empty, full cờ STT</span>',
         fill='#eff6ff', stroke='#60a5fa', stroke_w=1.5, font_size=11, font_color='#1e40af', z_index=3)

# On the right: u_rx_uart (receives PIN_AB22 directly!)
add_node('u_rx_uart', 1410, 578, 195, 122,
         '<b style="font-size:12px; color:#c2410c;">u_rx_uart Core</b><br/>'
         '<span style="font-size:11px; color:#334155;">rx_controller, baud_gen<br/>'
         'rx_sipo, deframe, err_chk<br/><hr style="margin:3px 0;"/>'
         '<b style="color:#ea580c;">PIN_AB22 (UART_RXD)</b></span>',
         fill='#fff7ed', stroke='#f97316', stroke_w=1.5, font_size=11, font_color='#c2410c', z_index=3)

# IRQ Line Warning
add_node('irq_box', 1185, 725, 430, 90,
         '<b style="font-size:12px; color:#b91c1c;">TÍN HIỆU NGẮT UART (IRQ LINE):</b><br/>'
         '<span style="font-size:11px; color:#991b1b;">irq = (RX_ready &amp; IER[0]) | (TX_idle &amp; IER[1]) | (overrun &amp; IER[2])</span><br/>'
         '<b style="font-size:11px; color:#dc2626;">[CẢNH BÁO]: Trong system.v đang nối .irq() rỗng; BSP set IRQ=-1.<br/>CPU Nios V/c hiện tại chỉ chạy chế độ POLLING!</b>',
         fill='#fef2f2', stroke='#ef4444', stroke_w=1.5, dashed=True, font_size=11, font_color='#b91c1c', z_index=2)

# =============================================================
# 7. CLOCK, RESET & NOTE STRIP (Bottom inside FPGA)
# =============================================================
add_node('clk_rst_box', 50, 845, 1580, 145, '', fill='#f8fafc', stroke='#64748b', stroke_w=1.5, rounded=1, z_index=1)

add_node('clk_box', 65, 855, 480, 125,
         '<b style="font-size:12px; color:#0f172a;">CLOCK DISTRIBUTION (50 MHz)</b><br/><hr style="margin:4px 0;"/>'
         '<span style="font-size:11px; color:#334155; line-height:1.45;">'
         '• <b>CLOCK_50 (PIN_Y2):</b> Bộ tạo dao động 50 MHz trên board DE2-115.<br/>'
         '• Cấp xung nhịp PCLK đồng bộ cho CPU Nios V/c, Interconnect Merlin,<br/>'
         '&nbsp;&nbsp;Custom APB UART, On-chip RAM, JTAG UART và PIO.'
         '</span>',
         fill='#ffffff', stroke='#94a3b8', stroke_w=1, font_size=11, font_color='#0f172a', align='left', z_index=2)

add_node('rst_box', 565, 855, 480, 125,
         '<b style="font-size:12px; color:#0f172a;">RESET CONTROLLER (Active-Low)</b><br/><hr style="margin:4px 0;"/>'
         '<span style="font-size:11px; color:#334155; line-height:1.45;">'
         '• <b>KEY[0] (PIN_M23):</b> Nút nhấn Reset trên board DE2-115.<br/>'
         '• Altera Reset Controller đồng bộ hóa và sinh tín hiệu <b>rst_n / preset_n</b><br/>'
         '&nbsp;&nbsp;tích cực thấp reset toàn bộ hệ thống SoC.'
         '</span>',
         fill='#ffffff', stroke='#94a3b8', stroke_w=1, font_size=11, font_color='#0f172a', align='left', z_index=2)

add_node('note_bridge_box', 1065, 855, 550, 125,
         '<b style="font-size:12px; color:#b45309;">PHÂN BIỆT VỚI BRIDGE VIẾT TAY (avalon2apb.v):</b><br/><hr style="margin:4px 0;"/>'
         '<span style="font-size:11px; color:#78350f; line-height:1.45;">'
         '• File <i>avalon2apb.v</i> là bridge độc lập có sẵn trong repo nhưng <b>chưa được nối<br/>'
         '&nbsp;&nbsp;vào hệ thống Quartus này</b>.<br/>'
         '• Hệ thống thực tế đang dùng <b>APB Slave Agent tự động của Merlin</b> để chuyển<br/>'
         '&nbsp;&nbsp;đổi yêu cầu từ AXI4-Lite sang APB.'
         '</span>',
         fill='#fefce8', stroke='#f59e0b', stroke_w=1.5, font_size=11, font_color='#b45309', align='left', z_index=2)

# =============================================================
# 8. EXTERNAL ENVIRONMENT (Right Column - Pristine Alignment!)
# =============================================================
# Level 1: Board JTAG TAP & User I/O (Aligned with RAM, JTAG, PIO at Top)
add_node('board_top_io', 1710, 180, 400, 110,
         '<b style="font-size:13px; color:#0f766e;">JTAG TAP &amp; NGOẠI VI DE2-115</b><br/><hr style="margin:4px 0;"/>'
         '<div style="text-align:left; font-size:11px; color:#134e4a; line-height:1.4; padding-left:4px;">'
         '• <b>JTAG TAP Header:</b> Cáp nạp USB-Blaster on-board<br/>'
         '• <b>Conduit User I/O:</b> LEDG[7:0], HEX0..1, SW[7:0], KEY[1]'
         '</div>',
         fill='#ffffff', stroke='#0d9488', stroke_w=2, font_size=11, font_color='#134e4a', align='left', z_index=2)

# Level 2: Board UART Pins (Aligned directly with UART TX/RX cores!)
add_node('board_uart_pins', 1710, 365, 400, 215,
         '<b style="font-size:14px; color:#0f766e;">CHÂN CẮM UART BOARD DE2-115</b><br/><hr style="margin:4px 0;"/>'
         '<div style="text-align:left; font-size:11px; color:#134e4a; line-height:1.45; padding-left:4px;">'
         '• <b>UART_TXD (PIN_AC15):</b> Đầu ra serial từ u_tx_uart<br/>'
         '• <b>UART_RXD (PIN_AB22):</b> Đầu vào serial tới u_rx_uart<br/>'
         '• <b>Mức điện áp:</b> 3.3-V LVTTL, chung GND với adapter<br/>'
         '• <b>Tốc độ baud:</b> 9600 baud, khung truyền 8N1'
         '</div>',
         fill='#ffffff', stroke='#0d9488', stroke_w=2, font_size=11, font_color='#134e4a', align='left', z_index=2)

# Level 3: USB-UART Adapter (ESP32 / CP2102)
add_node('usb_adapter', 1710, 605, 400, 170,
         '<b style="font-size:14px; color:#0f766e;">MẠCH CẦU USB-UART (ESP32 / CP2102)</b><br/><hr style="margin:4px 0;"/>'
         '<div style="text-align:left; font-size:11px; color:#134e4a; line-height:1.45; padding-left:4px;">'
         '• <b>Chuyển đổi:</b> Tín hiệu USB (PC) ↔ Serial TTL 3.3V (FPGA)<br/>'
         '• <b>Đấu dây GPIO chéo:</b><br/>'
         '&nbsp;&nbsp;- TX Adapter → RX FPGA (PIN_AB22)<br/>'
         '&nbsp;&nbsp;- RX Adapter ← TX FPGA (PIN_AC15)<br/>'
         '&nbsp;&nbsp;- Chân GND nối chung giữa board FPGA và module'
         '</div>',
         fill='#ffffff', stroke='#0d9488', stroke_w=2, font_size=11, font_color='#134e4a', align='left', z_index=2)

# Level 4: PC Host & Terminals
add_node('pc_host', 1710, 800, 400, 195,
         '<b style="font-size:15px; color:#0f766e;">MÁY TÍNH CÁ NHÂN (PC / HOST)</b><br/><hr style="margin:4px 0;"/>'
         '<div style="text-align:left; font-size:11px; color:#134e4a; line-height:1.45; padding-left:4px;">'
         '• <b>Serial Terminal (PuTTY / TeraTerm / screen):</b><br/>'
         '&nbsp;&nbsp;- Cổng COMx (Windows) hoặc /dev/ttyUSB0 (Linux)<br/>'
         '&nbsp;&nbsp;- <b>9600 baud, 8N1</b> (giao tiếp trực tiếp với APB UART)<br/>'
         '• <b>JTAG Terminal (niosv-terminal):</b><br/>'
         '&nbsp;&nbsp;- Console debug độc lập qua USB-Blaster tới jtag_uart_0'
         '</div>',
         fill='#ffffff', stroke='#0d9488', stroke_w=2, font_size=11, font_color='#134e4a', align='left', z_index=2)

# =============================================================
# 9. BOTTOM CALLOUT / LEGEND CARDS (Three detailed slide cards)
# =============================================================
add_node('card1', 30, 1035, 680, 195,
         '<b style="font-size:13px; color:#581c87;">ĐẶC TẢ 81 DÂY LOGIC APB3 (INTERCONNECT ↔ APB_SLAVE)</b><br/><hr style="margin:4px 0;"/>'
         '<div style="text-align:left; font-size:11px; color:#1e293b; line-height:1.45; padding-left:4px;">'
         '• <b>Master → Slave (47 dây):</b><br/>'
         '&nbsp;&nbsp;paddr[11:0] (12b offset), psel (1b), penable (1b), pwrite (1b), pwdata[31:0] (32b ghi)<br/>'
         '• <b>Slave → Master (34 dây):</b><br/>'
         '&nbsp;&nbsp;prdata[31:0] (32b đọc), pready (1b bắt tay), pslverr (1b báo lỗi giao dịch)<br/>'
         '• <b>Đặc điểm:</b> 81 dây logic nội bộ FPGA (không phải chân cắm board); PREADY=1 tại pha ACCESS giúp hoàn tất sau 2 chu kỳ clock (SETUP → ACCESS) mà không cần wait-state.'
         '</div>',
         fill='#faf5ff', stroke='#a855f7', stroke_w=2, font_size=11, font_color='#581c87', align='left', z_index=2)

add_node('card2', 740, 1035, 690, 195,
         '<b style="font-size:13px; color:#1e3a8a;">PHÂN BIỆT 3 CẤP TÊN TRÁNH NHẦM LẪN KHI ĐỌC CODE</b><br/><hr style="margin:4px 0;"/>'
         '<div style="text-align:left; font-size:11px; color:#1e293b; line-height:1.45; padding-left:4px;">'
         '• <b>apb_uart_0:</b> Tên Instance IP do Platform Designer quản lý và sinh netlist cấp hệ thống.<br/>'
         '• <b>apb_uart_0.apb_slave:</b> Tên Giao diện Interface APB chuẩn khai báo trong file <i>apb_uart_hw.tcl</i>.<br/>'
         '• <b>apb_uart_0.u_apb_slave:</b> Tên Module con Verilog (<i>apb_slave.v</i>) thực hiện logic giải mã bus APB.<br/>'
         '• <b>Bản chất:</b> Interface là quy tắc kết nối; Module là mạch vật lý; không đồng nhất interface với một module.'
         '</div>',
         fill='#eff6ff', stroke='#3b82f6', stroke_w=2, font_size=11, font_color='#1e3a8a', align='left', z_index=2)

add_node('card3', 1460, 1035, 670, 195,
         '<b style="font-size:13px; color:#b45309;">VÍ DỤ LUỒNG MMIO WRITE KÝ TỰ \'A\' (0x41) VÀO TX</b><br/><hr style="margin:4px 0;"/>'
         '<div style="text-align:left; font-size:11px; color:#1e293b; line-height:1.45; padding-left:4px;">'
         '• <b>1. CPU:</b> Lệnh C <code>IOWR_32DIRECT(0x20000, 0x00, 0x41)</code> phát yêu cầu AXI4-Lite write.<br/>'
         '• <b>2. Merlin:</b> NI đóng gói packet 106-bit; Router chuyển đến APB Agent tại offset 0x000.<br/>'
         '• <b>3. APB Agent:</b> Tạo chu kỳ SETUP (PENABLE=0) rồi ACCESS (PENABLE=1) với PWDATA=0x41.<br/>'
         '• <b>4. UART IP:</b> u_apb_slave trả PREADY=1; u_uart_regs nạp 0x41 vào u_tx_fifo.<br/>'
         '• <b>5. Core TX:</b> Rút byte từ FIFO và phát nối tiếp 8N1 ra chân PIN_AC15 (~1.042 ms trên dây).'
         '</div>',
         fill='#fffbeb', stroke='#f59e0b', stroke_w=2, font_size=11, font_color='#b45309', align='left', z_index=2)

# =============================================================
# 10. EDGES & BUS CONNECTIONS (Clear routing, zero crossing)
# =============================================================

# Edge 1: CPU Data Manager -> Merlin AXI NI (AXI4-Lite)
add_edge('e_cpu_dm_merlin', 'cpu_dm_box', 'merlin_ni',
         [(310, 480), (350, 480), (350, 280), (405, 280)],
         label='AXI4-Lite MMIO\n(AW, W, B, AR, R)',
         color='#2563eb', stroke_w=3, both=True, font_size=10,
         label_pos=(350, 380))

# Edge 2: CPU Instruction Manager -> Merlin Router (AXI4-Lite)
add_edge('e_cpu_im_router', 'cpu_im_box', 'merlin_router',
         [(310, 350), (405, 350)],
         label='AXI4-Lite Lệnh',
         color='#2563eb', stroke_w=2, both=True, font_size=10,
         label_pos=(355, 335))

# Edge 3: Merlin NI -> Merlin Router
add_edge('e_ni_router', 'merlin_ni', 'merlin_router',
         [(595, 323), (595, 332)],
         label='', color='#ca8a04', stroke_w=2.5, both=True)

# Edge 4: Merlin Router -> APB Slave Agent
add_edge('e_router_agent', 'merlin_router', 'merlin_apb_agent',
         [(595, 472), (595, 482)],
         label='Command / Response (106b)',
         color='#ca8a04', stroke_w=2.5, both=True, font_size=10)

# Edge 5: APB Slave Agent -> APB Translator
add_edge('e_agent_trans', 'merlin_apb_agent', 'merlin_apb_trans',
         [(595, 642), (595, 652)],
         label='', color='#9333ea', stroke_w=2.5, both=True)

# Avalon-MM Bus Trunk from Merlin Router to RAM, JTAG UART, PIO:
add_edge('e_router_ram', 'merlin_router', 'ram_box',
         [(785, 360), (840, 360), (840, 305), (997, 305), (997, 290)],
         label='Avalon-MM (0x00000)',
         color='#16a34a', stroke_w=2, both=True, font_size=10,
         label_pos=(860, 320))

add_edge('e_router_jtag', 'merlin_router', 'jtag_box',
         [(840, 305), (1242, 305), (1242, 290)],
         label='Avalon-MM (0x10010)',
         color='#16a34a', stroke_w=2, both=True, font_size=10,
         label_pos=(1140, 305))

add_edge('e_router_pio', 'merlin_router', 'pio_box',
         [(1242, 305), (1500, 305), (1500, 290)],
         label='Avalon-MM (0x10000/20/30)',
         color='#16a34a', stroke_w=2, both=True, font_size=10,
         label_pos=(1370, 305))

# Edge 9: APB Translator -> u_apb_slave (APB 81 wires in wide corridor!)
add_edge('e_trans_slave', 'merlin_apb_trans', 'u_apb_slave',
         [(785, 695), (855, 695), (855, 482), (925, 482)],
         label='APB 81 dây logic\nM→S (47b): paddr, psel,\npenable, pwrite, pwdata\nS→M (34b): prdata,\npready, pslverr',
         color='#7c3aed', stroke_w=3.5, both=True, font_size=10,
         label_pos=(855, 545))

# Edge 10: u_apb_slave -> u_uart_regs (Internal Reg Interface)
add_edge('e_slave_regs', 'u_apb_slave', 'u_uart_regs',
         [(1042, 600), (1042, 625)],
         label='Giao diện Reg nội bộ',
         color='#ea580c', stroke_w=2.5, both=True, font_size=10,
         label_pos=(1042, 612))

# Edge 11: u_uart_regs -> TX FIFO
add_edge('e_regs_txfifo', 'u_uart_regs', 'u_tx_fifo',
         [(1160, 680), (1175, 680), (1175, 460), (1195, 460)],
         label='tx_fifo_wr_en, wr_data[7:0]',
         color='#2563eb', stroke_w=2, both=False, font_size=10,
         label_pos=(1175, 520))

# Edge 12: u_tx_fifo -> u_tx_uart
add_edge('e_txfifo_txuart', 'u_tx_fifo', 'u_tx_uart',
         [(1390, 460), (1410, 460)],
         label='load_reg',
         color='#2563eb', stroke_w=2, both=False, font_size=10)

# Edge 13: u_tx_uart -> Board UART Pins (DIRECT HORIZONTAL TX!)
add_edge('e_tx_board', 'u_tx_uart', 'board_uart_pins',
         [(1605, 460), (1710, 460)],
         label='UART_TXD (PIN_AC15)',
         color='#2563eb', stroke_w=3, both=False, font_size=11,
         label_pos=(1657, 445))

# Edge 14: Board UART Pins -> u_rx_uart (DIRECT HORIZONTAL RX!)
add_edge('e_board_rx', 'board_uart_pins', 'u_rx_uart',
         [(1710, 640), (1605, 640)],
         label='UART_RXD (PIN_AB22)',
         color='#2563eb', stroke_w=3, both=False, font_size=11,
         label_pos=(1657, 625))

# Edge 15: u_rx_uart -> u_rx_fifo (Right to Left inside RX path!)
add_edge('e_rxuart_rxfifo', 'u_rx_uart', 'u_rx_fifo',
         [(1410, 640), (1390, 640)],
         label='push_data',
         color='#2563eb', stroke_w=2, both=False, font_size=10)

# Edge 16: u_rx_fifo -> u_uart_regs (DIRECT HORIZONTAL into Regs!)
add_edge('e_rxfifo_regs', 'u_rx_fifo', 'u_uart_regs',
         [(1195, 640), (1160, 640)],
         label='rx_fifo_rd_en, dout[8:0]',
         color='#2563eb', stroke_w=2, both=False, font_size=10,
         label_pos=(1177, 655))

# Edge 17: Board UART Pins <-> USB-UART Adapter
add_edge('e_board_adapter', 'board_uart_pins', 'usb_adapter',
         [(1910, 580), (1910, 605)],
         label='Tín hiệu TTL 3.3V (TX/RX chéo &amp; GND)',
         color='#0d9488', stroke_w=2.5, both=True, font_size=11)

# Edge 18: USB-UART Adapter <-> PC Host
add_edge('e_adapter_pc', 'usb_adapter', 'pc_host',
         [(1910, 775), (1910, 800)],
         label='Cáp USB (COMx / /dev/ttyUSB0)',
         color='#0d9488', stroke_w=2.5, both=True, font_size=11)

# Edge 19: JTAG UART -> Board JTAG TAP Header (Clear corridor ABOVE PIO at y=160!)
add_edge('e_jtag_board', 'jtag_box', 'board_top_io',
         [(1350, 210), (1360, 210), (1360, 160), (1690, 160), (1690, 210), (1710, 210)],
         label='JTAG Bus (TCK, TMS, TDI, TDO)',
         color='#16a34a', stroke_w=2, both=True, font_size=10,
         label_pos=(1525, 150))

# Edge 20: PIO -> Board User I/O (Direct horizontal!)
add_edge('e_pio_board', 'pio_box', 'board_top_io',
         [(1620, 250), (1710, 250)],
         label='Conduit GPIO',
         color='#16a34a', stroke_w=2, both=True, font_size=10,
         label_pos=(1665, 238))


# =============================================================
# XML GENERATOR (draw.io mxGraphModel)
# =============================================================
def build_drawio_xml():
    mxGraphModel = ET.Element('mxGraphModel', {
        'dx': '1800', 'dy': '1100', 'grid': '1', 'gridSize': '10',
        'guides': '1', 'tooltips': '1', 'connect': '1', 'arrows': '1',
        'fold': '1', 'page': '1', 'pageScale': '1',
        'pageWidth': str(WIDTH), 'pageHeight': str(HEIGHT),
        'background': '#ffffff'
    })
    root = ET.SubElement(mxGraphModel, 'root')
    ET.SubElement(root, 'mxCell', id='0')
    ET.SubElement(root, 'mxCell', id='1', parent='0')

    for n in sorted(nodes, key=lambda x: x['z_index']):
        style = (
            f"rounded={n['rounded']};whiteSpace=wrap;html=1;"
            f"fillColor={n['fill']};strokeColor={n['stroke']};strokeWidth={n['stroke_w']};"
            f"fontSize={n['font_size']};fontColor={n['font_color']};fontFamily=Helvetica,Arial,sans-serif;"
        )
        if n['dashed']:
            style += "dashed=1;dashPattern=6 4;"
        if n['align'] == 'left':
            style += "align=left;spacingLeft=8;"
        else:
            style += "align=center;"

        cell = ET.SubElement(root, 'mxCell', {
            'id': n['id'],
            'value': n['label'],
            'style': style,
            'vertex': '1',
            'parent': '1'
        })
        ET.SubElement(cell, 'mxGeometry', {
            'x': str(n['x']), 'y': str(n['y']),
            'width': str(n['w']), 'height': str(n['h']),
            'as': 'geometry'
        })

    for e in edges:
        style = (
            f"html=1;rounded=0;strokeWidth={e['stroke_w']};strokeColor={e['color']};"
            f"fontSize={e['font_size']};fontFamily=Helvetica,Arial,sans-serif;labelBackgroundColor={e['label_bg']};"
            "endArrow=classic;"
        )
        if e['both']:
            style += "startArrow=classic;"
        if e['dashed']:
            style += "dashed=1;"

        cell = ET.SubElement(root, 'mxCell', {
            'id': e['id'],
            'value': e['label'].replace('\n', '<br/>'),
            'style': style,
            'edge': '1',
            'parent': '1',
            'source': e['src'],
            'target': e['dst']
        })
        geo = ET.SubElement(cell, 'mxGeometry', {'relative': '1', 'as': 'geometry'})
        ET.SubElement(geo, 'mxPoint', {'x': str(e['points'][0][0]), 'y': str(e['points'][0][1]), 'as': 'sourcePoint'})
        ET.SubElement(geo, 'mxPoint', {'x': str(e['points'][-1][0]), 'y': str(e['points'][-1][1]), 'as': 'targetPoint'})
        if len(e['points']) > 2:
            arr = ET.SubElement(geo, 'Array', {'as': 'points'})
            for pt in e['points'][1:-1]:
                ET.SubElement(arr, 'mxPoint', {'x': str(pt[0]), 'y': str(pt[1])})

    xml_str = ET.tostring(mxGraphModel, encoding='utf-8', xml_declaration=False).decode('utf-8')
    return xml_str

# =============================================================
# SVG VECTOR GENERATOR
# =============================================================
def build_svg():
    svg = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{HEIGHT}" viewBox="0 0 {WIDTH} {HEIGHT}" font-family="DejaVu Sans, Segoe UI, Helvetica, Arial, sans-serif">',
        '  <defs>',
        '    <marker id="arrow-blue" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0 1 L10 5 L0 9 z" fill="#2563eb"/></marker>',
        '    <marker id="arrow-purple" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0 1 L10 5 L0 9 z" fill="#7c3aed"/></marker>',
        '    <marker id="arrow-amber" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0 1 L10 5 L0 9 z" fill="#ca8a04"/></marker>',
        '    <marker id="arrow-orange" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0 1 L10 5 L0 9 z" fill="#ea580c"/></marker>',
        '    <marker id="arrow-green" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0 1 L10 5 L0 9 z" fill="#16a34a"/></marker>',
        '    <marker id="arrow-teal" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0 1 L10 5 L0 9 z" fill="#0d9488"/></marker>',
        '  </defs>',
        '  <rect width="100%" height="100%" fill="#ffffff"/>'
    ]

    # Draw nodes
    for n in sorted(nodes, key=lambda x: x['z_index']):
        dash = ' stroke-dasharray="6,4"' if n['dashed'] else ''
        rx = 8 if n['rounded'] else 0
        fill = n['fill'] if n['fill'] != 'none' else 'none'
        stroke = n['stroke'] if n['stroke'] != 'none' else 'none'
        svg.append(f'  <rect x="{n["x"]}" y="{n["y"]}" width="{n["w"]}" height="{n["h"]}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="{n["stroke_w"]}"{dash}/>')
        
        if n['label']:
            align_style = "text-align: left; padding: 4px;" if n['align'] == 'left' else "text-align: center;"
            clean_lbl = n["label"].replace('&nbsp;', '&#160;')
            svg.append(f'  <foreignObject x="{n["x"]}" y="{n["y"]}" width="{n["w"]}" height="{n["h"]}"><div xmlns="http://www.w3.org/1999/xhtml" style="width:100%; height:100%; box-sizing:border-box; {align_style} font-size:{n["font_size"]}px; color:{n["font_color"]}; font-family:inherit;">{clean_lbl}</div></foreignObject>')

    # Draw edges
    for e in edges:
        pts = ' '.join(f"{p[0]},{p[1]}" for p in e['points'])
        col = e['color']
        marker_id = 'arrow-blue'
        if '7c3aed' in col or '9333ea' in col: marker_id = 'arrow-purple'
        elif 'ca8a04' in col or 'eab308' in col: marker_id = 'arrow-amber'
        elif 'ea580c' in col or 'f97316' in col: marker_id = 'arrow-orange'
        elif '16a34a' in col or '22c55e' in col: marker_id = 'arrow-green'
        elif '0d9488' in col: marker_id = 'arrow-teal'

        start_m = f' marker-start="url(#{marker_id})"' if e['both'] else ''
        end_m = f' marker-end="url(#{marker_id})"'
        dash = ' stroke-dasharray="5,4"' if e['dashed'] else ''
        svg.append(f'  <polyline points="{pts}" fill="none" stroke="{col}" stroke-width="{e["stroke_w"]}"{start_m}{end_m}{dash}/>')

        if e['label']:
            if e.get('label_pos'):
                lx, ly = e['label_pos']
            else:
                mid_idx = len(e['points']) // 2
                p1 = e['points'][mid_idx - 1]
                p2 = e['points'][mid_idx]
                lx = (p1[0] + p2[0]) / 2
                ly = (p1[1] + p2[1]) / 2 - 8
            
            lines = e['label'].split('\n')
            for i, line in enumerate(lines):
                ey = ly + (i - (len(lines) - 1) / 2) * 15
                clean_line = html.escape(line).replace('&amp;amp;', '&amp;')
                svg.append(f'  <text x="{lx}" y="{ey}" text-anchor="middle" font-size="{e["font_size"]}" fill="{col}" font-weight="bold" stroke="#ffffff" stroke-width="4" paint-order="stroke">{clean_line}</text>')

    svg.append('</svg>')
    return '\n'.join(svg)

def main():
    xml_content = build_drawio_xml()
    svg_content = build_svg()

    # 1. Write raw XML
    XML_OUT.write_text(xml_content, encoding='utf-8')
    print(f"Generated raw XML: {XML_OUT} ({len(xml_content)} bytes)")

    # 2. Write .drawio
    mxfile = f'<mxfile host="app.diagrams.net" modified="2026-10-16T16:30:00.000Z" agent="Mozilla/5.0" version="24.0.0" type="device"><diagram id="cpu_apb_uart" name="01 SoC AXI to APB UART">{xml_content}</diagram></mxfile>'
    DRAWIO_OUT.write_text(mxfile, encoding='utf-8')
    print(f"Generated draw.io file: {DRAWIO_OUT}")

    # 3. Write SVG
    SVG_OUT.write_text(svg_content, encoding='utf-8')
    print(f"Generated SVG vector: {SVG_OUT}")

    # 4. Write JSON
    json_data = {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "diagram_title": "Kiến trúc hệ thống: Nios V/c (AXI4-Lite) → Interconnect Merlin → APB UART (Cyclone IV SoC)",
        "version": "3.0",
        "date": "2026-10-16",
        "description": "Mã nguồn XML draw.io mxGraphModel chuẩn xác, chi tiết từng chân AXI4-Lite, bộ chuyển đổi Merlin, APB 81 dây logic, thanh ghi UART và FIFO, tối ưu hóa cho slide thuyết trình.",
        "hardware_platform": {
            "fpga_part": "EP4CE115F29C7 (Cyclone IV E)",
            "board": "Terasic DE2-115",
            "quartus_project": "/home/vietanh/altera_lite/24.1std",
            "qsys_system": "system.qsys",
            "top_module": "NIOS.v"
        },
        "bus_architecture": {
            "cpu_bus": "AXI4-Lite Master (enableAvalonInterface=false, 5 channels: AW, W, B, AR, R)",
            "interconnect": "mm_interconnect_0 (Platform Designer Merlin)",
            "interconnect_modules": [
                "altera_merlin_axi_master_ni (intel_niosv_c_0_data_manager_agent)",
                "merlin_packet_switch_router (106-bit Command/Response packets)",
                "altera_merlin_apb_slave_agent (FSM: IDLE -> SETUP -> ACCESS -> SEND_RESPONSE)",
                "altera_merlin_apb_translator (ADDR_WIDTH=12, DATA_WIDTH=32, USE_M0_PSLVERR=1)"
            ],
            "apb_interface_signals_81_wires": {
                "master_to_slave_47b": ["paddr[11:0]", "psel", "penable", "pwrite", "pwdata[31:0]"],
                "slave_to_master_34b": ["prdata[31:0]", "pready", "pslverr"]
            },
            "apb_uart_internal_modules": {
                "u_apb_slave": "Pure combinational decoder (apb_slave.v, no FSM, pready = psel & penable)",
                "u_uart_regs": "Register file (uart_regs.v: 0x00 TX, 0x04 RX, 0x08 CFG, 0x0C STT, 0x10 IER)",
                "tx_path": "u_tx_fifo (16x8) -> u_tx_uart core -> PIN_AC15",
                "rx_path": "PIN_AB22 -> u_rx_uart core -> u_rx_fifo (16x9) -> u_uart_regs"
            },
            "interrupt_status": "UART IRQ line unconnected in system.v (.irq()); software uses polling mode",
            "manual_bridge_status": "avalon2apb.v exists in repository but is NOT instantiated in this Quartus SoC"
        },
        "diagram_dimensions": {
            "width": WIDTH,
            "height": HEIGHT,
            "aspect_ratio": "16:9 (Slide Ready)"
        },
        "xml_content": xml_content
    }

    JSON_OUT.write_text(json.dumps(json_data, indent=2, ensure_ascii=False), encoding='utf-8')
    print(f"Generated JSON file: {JSON_OUT} ({len(JSON_OUT.read_text())} bytes)")

if __name__ == '__main__':
    main()

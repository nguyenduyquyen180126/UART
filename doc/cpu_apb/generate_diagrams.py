"""Generate editable draw.io diagrams and SVG from the same explicit topology."""
from pathlib import Path
import html
import xml.etree.ElementTree as E

OUT = Path(__file__).resolve().parent
pages = []
def page(name, subtitle, width=1800, height=1040):
    p=dict(name=name,subtitle=subtitle,width=width,height=height,nodes=[],edges=[])
    pages.append(p)
    return p
def node(p,id,x,y,w,h,label,fill='#e7efff',stroke='#4567a0',dashed=False):
    p['nodes'].append(dict(id=id,x=x,y=y,w=w,h=h,label=label,fill=fill,stroke=stroke,dashed=dashed))
def edge(p,a,b,points,label='',color='#315fc1',both=False,dashed=False):
    p['edges'].append(dict(a=a,b=b,points=points,label=label,color=color,both=both,dashed=dashed))
p=page('01 SoC — HDL đã sinh','CPU AXI4-Lite → interconnect Merlin → APB UART | RAM có trong HDL; đang tắt trong system.qsys')
node(p,'cpu',40,190,245,150,'Nios V/c\nintel_niosv_c_0\ndata: AXI4-Lite\ninstruction: AXI4-Lite')
node(p,'fabric',390,170,370,210,'mm_interconnect_0\nAXI master NI\nRouter / mux / demux\nAPB slave agent + translator\nAvalon agents cho RAM / PIO / JTAG','#fff2cc','#b68b21')
node(p,'ram',970,115,300,105,'On-chip RAM: 64 KiB\n0x00000000 .. 0x0000FFFF\nHDL: co | qsys: enabled=0','#f1f2f5','#687386',True)
node(p,'apb',970,300,300,100,'apb_uart_0.apb_slave\nAPB: addr 12, data 32\n0x00020000 .. 0x00020FFF','#e8dcff','#8155a5')
node(p,'jtag',970,465,300,90,'jtag_uart_0\nAvalon-MM target\n0x00010010 .. 0x00010017','#e4f6e7','#418552')
node(p,'pio',970,625,300,105,'PIO output 8 / SW 8 / KEY 1\nAvalon-MM targets\n0x10000 / 0x10020 / 0x10030','#e4f6e7','#418552')
node(p,'uart',1380,300,340,150,'Ben trong apb_uart_0\napb_slave -> uart_regs\nTX FIFO 16 x 8 -> TX core\nRX core -> RX FIFO 16 x 9','#ffe9df','#b65b37')
node(p,'serial',1380,540,340,110,'USB-UART TTL 3.3 V\nTX FPGA -> RX adapter\nTX adapter -> RX FPGA\nChung GND','#e0f5f8','#36808c')
node(p,'pcserial',1380,760,340,80,'PC: Serial terminal\n9600 baud, 8N1 trong main.c','#e0f5f8','#36808c')
node(p,'pcjtag',525,500,300,100,'PC: JTAG terminal\nUSB-Blaster / JTAG\nDuong debug rieng','#e4f6e7','#418552')
node(p,'clk',40,660,350,100,'CLOCK_50 = 50 MHz\nKEY[0] -> reset controller\nClock/reset cap song song cho IP','#f1f2f5','#687386')
node(p,'note',40,880,1680,90,'Duong xanh: giao dich bo nho hai chieu. IRQ UART dang de ho.\nKhong co instance avalon2apb.v trong HDL nay. Mau bus xac dinh bang interface/HDL, khong bang mau day tren Schematic.','#fff2cc','#b68b21')
edge(p,'cpu','fabric',[(285,245),(390,245)],'AXI4-Lite',both=True)
edge(p,'fabric','ram',[(760,200),(860,200),(860,165),(970,165)],'Avalon-MM',both=True)
edge(p,'fabric','apb',[(760,350),(970,350)],'APB',both=True)
edge(p,'fabric','jtag',[(760,375),(870,375),(870,510),(970,510)],'Avalon-MM',both=True)
edge(p,'fabric','pio',[(575,380),(575,430),(910,430),(910,675),(970,675)],'Avalon-MM',both=True)
edge(p,'apb','uart',[(1270,350),(1380,350)],'APB 81 day',both=True)
edge(p,'jtag','pcjtag',[(970,545),(825,545)],'JTAG',both=True,color='#418552')
edge(p,'uart','serial',[(1550,450),(1550,540)],'UART TX / RX',both=True,color='#b65b37')
edge(p,'serial','pcserial',[(1550,650),(1550,760)],'USB',both=True,color='#36808c')

p=page('02 CPU đến từng chân APB','Dây thật trong HDL | APB master nằm trong agent; APB slave nằm trong UART',1800,1160)
node(p,'cpu',40,150,300,145,'Nios V/c data_manager\nAW / W / B / AR / R\nADDR 32, DATA 32, WSTRB 4\nMoi kenh: VALID & READY')
node(p,'ni',440,150,355,145,'intel_niosv_c_0_\ndata_manager_agent\naltera_merlin_axi_master_ni\nAXI_VERSION = AXI4Lite','#fff2cc','#b68b21')
node(p,'net',895,150,360,145,'Merlin command / response\nPacket DATA 106 bit\nvalid, ready, SOP, EOP\nRouter chon UART tai 0x20000','#fff2cc','#b68b21')
node(p,'agent',1355,150,390,145,'apb_uart_0_apb_slave_agent\naltera_merlin_apb_slave_agent\nIDLE -> SET_UP -> ACCESS\n-> SEND_RESPONSE','#e8dcff','#8155a5')
edge(p,'cpu','ni',[(340,220),(440,220)],'AXI4-Lite',both=True)
edge(p,'ni','net',[(795,220),(895,220)],'packets',both=True)
edge(p,'net','agent',[(1255,220),(1355,220)],'cp / rp',both=True)
node(p,'translator',1095,440,650,100,'apb_uart_0_apb_slave_translator\nADDR_WIDTH=12, DATA_WIDTH=32, USE_M0_PSLVERR=1\nPass-through APB; khong phai FSM doi AXI thanh APB','#e8dcff','#8155a5')
node(p,'slave',80,430,590,230,'apb_uart_0.u_apb_slave\nPREADY = PSEL & PENABLE\naddr_valid: aligned, 0x000 .. 0x010\nreg_pwrite = PSEL & PENABLE & valid & PWRITE\nreg_pread = PSEL & PENABLE & valid & ~PWRITE\nPSLVERR = ACCESS & (bad_addr | reg_ack_err)','#ffe9df','#b65b37')
edge(p,'agent','translator',[(1550,295),(1550,440)],'APB',both=True)
edge(p,'translator','slave',[(1095,455),(670,455)],'PADDR[11:0], PSEL, PENABLE',color='#315fc1')
edge(p,'translator','slave',[(1095,490),(670,490)],'PWRITE, PWDATA[31:0]',color='#315fc1')
edge(p,'slave','translator',[(670,535),(1095,535)],'PRDATA[31:0], PREADY, PSLVERR',color='#bb6c23')
node(p,'regs',80,800,590,190,'apb_uart_0.u_uart_regs\nTX 0x00 | RX 0x04 | CFG 0x08\nSTT 0x0C | IER 0x10\nClocked writes + FIFO side effects\nCombinational read mux','#e4f6e7','#418552')
node(p,'fifo',1095,800,650,190,'TX write: wr_en + pwdata[7:0] -> FIFO -> TX\nRX read: FIFO head -> prdata; pop at clock edge\nCFG -> baud_sel/data_bits/stop/parity\nIRQ = enabled RX ready / TX idle / overrun\nIRQ chua duoc noi den CPU','#e4f6e7','#418552')
edge(p,'slave','regs',[(245,660),(245,800)],'reg_paddr[11:0]\nreg_pwdata[31:0]\nreg_pread / reg_pwrite')
edge(p,'regs','slave',[(510,800),(510,660)],'reg_prdata[31:0]\nreg_ack_err',color='#bb6c23')
edge(p,'regs','fifo',[(670,900),(1095,900)],'Tin hieu noi bo rieng',both=True,color='#418552')
node(p,'note',80,1040,1665,65,'PCLK dung clk 50 MHz chung; reset UART la rst_n. APB request = 47 bit, response = 34 bit; tong 81 day logic, chua tinh clock/reset.','#f1f2f5','#687386')

p=page('03 Bridge Avalon viết tay','Phương án có trong repo; chưa được instantiate trong SoC Quartus đã kiểm tra',1800,860)
node(p,'host',60,240,360,250,'Avalon-MM host\nread / write / chipselect\naddress[11:0]\nwritedata[31:0]\nbyteenable[3:0]\nreaddata / waitrequest / response')
node(p,'bridge',650,240,440,250,'avalon2apb.v\nAvalon slave + APB master\nIDLE -> SETUP -> ACCESS\nwaitrequest=1 trong khi cho\nACCESS: waitrequest = !PREADY\nADDR_MODE 0: byte | 1: word','#fff2cc','#b68b21')
node(p,'uart',1320,240,360,250,'apb_uart\napb_slave -> uart_regs\nPADDR / PWDATA / PWRITE\nPSEL / PENABLE\nPRDATA / PREADY / PSLVERR\nFIFO va UART TX/RX','#ffe9df','#b65b37')
edge(p,'host','bridge',[(420,330),(650,330)],'Avalon-MM',both=True)
edge(p,'bridge','uart',[(1090,330),(1320,330)],'APB',both=True)
node(p,'note',60,590,1620,150,'Bridge dang bo qua avl_byteenable; APB khong co PSTRB. Chi dung MMIO 32-bit aligned cho cac vi du nay.\nPREADY=1 la xong giao dich thanh ghi, chua phai UART da phat xong 1 frame.\nMuon dung trong Platform Designer can dong goi component/tao wrapper va noi interface ro rang.','#fff2cc','#b68b21')

mx=E.Element('mxfile',host='app.diagrams.net',type='device')
for index,p in enumerate(pages):
    diagram=E.SubElement(mx,'diagram',id=f'page{index}',name=p['name'])
    model=E.SubElement(diagram,'mxGraphModel',dx='1800',dy='1100',grid='1',gridSize='10',page='1',pageWidth=str(p['width']),pageHeight=str(p['height']))
    root=E.SubElement(model,'root');E.SubElement(root,'mxCell',id='0');E.SubElement(root,'mxCell',id='1',parent='0')
    title=dict(id='title',x=30,y=20,w=p['width']-60,h=95,label=p['name']+'\n'+p['subtitle'],fill='#ffffff',stroke='#ffffff',dashed=False)
    for n in [title]+p['nodes']:
        style=f"rounded=1;whiteSpace=wrap;html=1;fillColor={n['fill']};strokeColor={n['stroke']};fontSize=18;spacing=12;"
        if n['dashed']:style+='dashed=1;'
        c=E.SubElement(root,'mxCell',id=n['id'],value=html.escape(n['label']).replace('\n','<br>'),style=style,vertex='1',parent='1')
        E.SubElement(c,'mxGeometry',x=str(n['x']),y=str(n['y']),width=str(n['w']),height=str(n['h']),attrib={'as':'geometry'})
    for j,e in enumerate(p['edges']):
        style=f"html=1;rounded=0;endArrow=classic;strokeWidth=2;strokeColor={e['color']};fontSize=16;labelBackgroundColor=#ffffff;"
        if e['both']:style+='startArrow=classic;'
        if e['dashed']:style+='dashed=1;'
        by_id={n['id']:n for n in p['nodes']}
        src=by_id[e['a']]; dst=by_id[e['b']]
        sx,sy=e['points'][0]; tx,ty=e['points'][-1]
        style+=f"exitX={(sx-src['x'])/src['w']};exitY={(sy-src['y'])/src['h']};entryX={(tx-dst['x'])/dst['w']};entryY={(ty-dst['y'])/dst['h']};exitDx=0;exitDy=0;entryDx=0;entryDy=0;"
        c=E.SubElement(root,'mxCell',id=f'e{j}',value=e['label'].replace('\n','<br>'),style=style,edge='1',parent='1',source=e['a'],target=e['b'])
        g=E.SubElement(c,'mxGeometry',relative='1',attrib={'as':'geometry'})
        for key,pt in [('sourcePoint',e['points'][0]),('targetPoint',e['points'][-1])]:E.SubElement(g,'mxPoint',x=str(pt[0]),y=str(pt[1]),attrib={'as':key})
        a=E.SubElement(g,'Array',attrib={'as':'points'})
        for pt in e['points'][1:-1]:E.SubElement(a,'mxPoint',x=str(pt[0]),y=str(pt[1]))
    # A code-native vector rendering, with no raster generation step.
    svg=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{p["width"]}" height="{p["height"]}" viewBox="0 0 {p["width"]} {p["height"]}">',
         '<defs><marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 z" fill="context-stroke"/></marker></defs>',
         '<rect width="100%" height="100%" fill="#fff"/>',
         f'<text x="30" y="45" font-family="DejaVu Sans,sans-serif" font-size="28" font-weight="bold" fill="#1b2c47">{html.escape(p["name"])}</text>',
         f'<text x="30" y="85" font-family="DejaVu Sans,sans-serif" font-size="18" fill="#475569">{html.escape(p["subtitle"])}</text>']
    for e in p['edges']:
        pts=' '.join(f'{x},{y}' for x,y in e['points']);start=' marker-start="url(#arrow)"' if e['both'] else ''
        svg.append(f'<polyline points="{pts}" fill="none" stroke="{e["color"]}" stroke-width="2.5" marker-end="url(#arrow)"{start}/>')
        pts2=list(zip(e['points'],e['points'][1:]));a,b=max(pts2,key=lambda ab:abs(ab[1][0]-ab[0][0]))
        lx=(a[0]+b[0])/2;ly=(a[1]+b[1])/2-10
        if abs(a[0]-b[0])<30:lx+=10
        label_lines=e['label'].split('\n')
        for k,line in enumerate(label_lines):
            ey=ly+(k-(len(label_lines)-1)/2)*22
            svg.append(f'<text x="{lx}" y="{ey}" text-anchor="middle" font-family="DejaVu Sans,sans-serif" font-size="16" fill="{e["color"]}" stroke="#fff" stroke-width="6" paint-order="stroke">{html.escape(line)}</text>')
    for n in p['nodes']:
        dash=' stroke-dasharray="8 5"' if n['dashed'] else ''
        svg.append(f'<rect x="{n["x"]}" y="{n["y"]}" width="{n["w"]}" height="{n["h"]}" rx="10" fill="{n["fill"]}" stroke="{n["stroke"]}" stroke-width="2"{dash}/>')
        lines=n['label'].split('\n');first=n['y']+n['h']/2-(len(lines)-1)*13+6
        for i,line in enumerate(lines):
            svg.append(f'<text x="{n["x"]+n["w"]/2}" y="{first+i*26}" text-anchor="middle" font-family="DejaVu Sans,sans-serif" font-size="18" fill="#17243b">{html.escape(line)}</text>')
    svg.append('</svg>');(OUT/f'architecture_{index+1}.svg').write_text('\n'.join(svg))
E.indent(mx);E.ElementTree(mx).write(OUT/'CPU_APB_UART.drawio',encoding='utf-8',xml_declaration=True)
print('Generated 3-page draw.io and 3 SVG diagrams.')

# APB UART characterization

Run `./scripts/measure_apb_uart.sh` from the repository root. Outputs are in
`build/uart_metrics/`; this is a standalone Cyclone IV E project, not a board
programming image. Nothing changes the SoC architecture or programs hardware.

The script fits the current RTL, constrains a 50 MHz clock, reports internal
register-to-register timing over the available operating corners, and runs
idle/active loopback power workloads on RTL and the post-fit functional netlist.
The gate simulation uses Icarus and Altera's installed Cyclone IV E atom models.
It does **not** annotate SDF. It can take several minutes and create several GB
of VCDs. These waveforms and generated databases are ignored by git.

`prepare_vcd.py` only removes testbench scope and renames the DUT root to match
the Quartus top; it does not synthesize switching activity. Power data comes
from actual simulations. Read Quartus's confidence and coverage tables before
using a power estimate. Full-chip static/I/O are not isolated UART power.

In-SoC timing is a separate optional step against the already fitted `NIOS`
project. The hierarchy filter includes `|apb_uart:apb_uart_0|` exactly so it cannot
accidentally include the similarly named Platform Designer APB slave agent.
The SoC fit must correspond to current logic before using its resource/timing
results. The characterization script does not rebuild or validate that SoC fit.

See `doc/reports/BAO_CAO_TAI_NGUYEN_FMAX_POWER_APB_UART_2026-10-17.md` for the measured
numbers, exact conditions, limitations, and saved evidence.

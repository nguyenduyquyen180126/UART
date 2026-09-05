# Verilog + ModelSim + Makefile Project Template

A simple, ready-to-use template for writing Verilog code, running simulations in ModelSim (Intel FPGA Edition or standard) using TCL scripts, and managing the workflow with a Makefile.

---

## 📁 Directory Structure

```text
├── rtl/                   # Design source files (Verilog)
│   └── counter.v          # Example: 4-bit synchronous up-counter
├── tb/                    # Testbench files
│   └── tb_counter.v       # Example: Testbench for the counter
├── sim/                   # ModelSim TCL scripts and wave setups
│   ├── run.tcl            # ModelSim script to compile and run sim
│   └── waves.do           # ModelSim wave window signals & config
├── Makefile               # Shortcuts to compile, run, and clean
├── .gitignore             # Ignores ModelSim workspace & temp outputs
└── README.md              # Project documentation (this file)
```

---

## 🚀 Getting Started

### 1. Prerequisites
- **ModelSim / QuestaSim** installed.
- **GNU Make** installed (or Git Bash, MSYS2, or wmake on Windows).

### 2. Configure ModelSim Path
Open the `Makefile` and update the `VSIM` variable if your ModelSim path differs from the default:
```makefile
VSIM ?= "C:/intelFPGA/20.1/modelsim_ase/win32aloem/vsim.exe"
```
*Note: If `vsim` is already in your system's Environment Variables (`PATH`), you can simply change it to `VSIM ?= vsim`.*

---

## 🛠️ Usage Commands

Run these commands from the root directory of this folder:

### Run in GUI Mode (Interactive)
Compiles the design, opens ModelSim interface, adds signals to the Wave window, and runs the simulation:
```bash
make sim
```

### Run in CLI/Batch Mode (Non-interactive)
Runs the compilation and testbench outputs in the command terminal without opening the ModelSim GUI. Great for fast verification:
```bash
make sim_cli
```

### Clean Simulation Files
Deletes generated directories and files like `work/`, `transcript`, and `vsim.wlf`:
```bash
make clean
```

### Help Menu
Shows available targets:
```bash
make help
```

---

## 📦 How to Use This Template for New Projects

1. **Clone/Copy** this template folder to your workspace.
2. Place your design files (`.v`) in the `rtl/` directory.
3. Place your testbenches (`.v`) in the `tb/` directory.
4. Open `sim/run.tcl` and update the compilation commands to point to your new source files:
   ```tcl
   vlog rtl/your_module.v
   vlog tb/tb_your_module.v
   vsim -voptargs=+acc work.tb_your_module
   ```
5. Update `sim/waves.do` to list the signals you want to trace.
6. Run `make sim`!

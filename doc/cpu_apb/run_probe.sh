#!/usr/bin/env bash
# Runs in a temporary directory; leaves existing simulations and Quartus files alone.
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
quartus_project=${1:-/home/vietanh/altera_lite/24.1std}
probe_build=$(mktemp -d /tmp/uart-apb-probe.XXXXXX)
local_sources=("$repo_dir"/rtl/*.v)
merlin_sources=("$quartus_project/system/synthesis/submodules/altera_merlin_apb_slave_agent.sv" "$quartus_project/system/synthesis/submodules/altera_merlin_apb_translator.sv")
bench="$repo_dir/doc/cpu_apb/tb_bus_probe.sv"
run_case() {
    local case_name=$1
    shift
    iverilog -g2012 -s tb_bus_probe -o "$probe_build/$case_name.vvp" "$@" > "$probe_build/$case_name.compile.log" 2>&1 || {
        cat "$probe_build/$case_name.compile.log"
        return 1
    }
    vvp "$probe_build/$case_name.vvp" | tee "$probe_build/$case_name.run.log"
}
run_case custom-byte "$repo_dir/avalon2apb.v" "${local_sources[@]}" "$bench"
run_case custom-word -Ptb_bus_probe.ADDR_MODE=1 "$repo_dir/avalon2apb.v" "${local_sources[@]}" "$bench"
if [[ -f ${merlin_sources[0]} && -f ${merlin_sources[1]} ]]; then
    run_case merlin-local -Ptb_bus_probe.MERLIN=1 "${merlin_sources[@]}" "${local_sources[@]}" "$bench"
    deployed_sources=()
    for file in "${local_sources[@]}"; do
        deployed_sources+=("$quartus_project/system/synthesis/submodules/${file##*/}")
    done
    run_case merlin-quartus -Ptb_bus_probe.MERLIN=1 -Ptb_bus_probe.EXPECT_LAST_RX=1 "${merlin_sources[@]}" "${deployed_sources[@]}" "$bench"
else
    printf 'SKIP Merlin probes: generated Quartus sources absent at %s\n' "$quartus_project"
fi
# Existing APB regression, run away from the repository to avoid replacing its VCD.
iverilog -g2012 -s tb_apb_uart -o "$probe_build/apb.vvp" "${local_sources[@]}" "$repo_dir/tb/tb_apb_uart.v"
(cd -- "$probe_build" && vvp apb.vvp) > "$probe_build/apb.run.log"
tail -n 8 "$probe_build/apb.run.log"
printf 'Evidence and compile logs: %s\n' "$probe_build"

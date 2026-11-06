# APB UART characterization evidence — 2026-10-17

See `../../BAO_CAO_TAI_NGUYEN_FMAX_POWER_APB_UART_2026-10-17.md` for scope and interpretation.

- `uart_metrics.*`: standalone fitted UART resource and full-interface timing reports.
- `core_setup_*`, `core_hold_*`: standalone internal register-to-register paths.
- `soc_core_*`: paths filtered to the exact UART instance in the existing SoC.
- `soc_uart_resource_hierarchy.txt`: exact UART hierarchy rows from SoC Fitter.
- `power-*-25c.*`: power reports for RTL and post-fit functional VCD inputs.
- `*_sim.txt`: workload PASS logs; gate simulations have no SDF annotation.
- `results.json`: extracted values and RTL source SHA-256 fingerprints.
- `SHA256SUMS`: checksums of this evidence snapshot.

Generated VCDs, binaries and fit databases remain under ignored `build/uart_metrics/`.
These are estimates/STA results under declared conditions, not board power measurements.

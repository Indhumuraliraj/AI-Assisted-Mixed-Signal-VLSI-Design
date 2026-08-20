#!/usr/bin/env bash
###############################################################################
# scripts/run_lvs.sh
# Runs Netgen LVS: extracted AMUX2_3V netlist vs. schematic/verilog reference.
###############################################################################
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PDK_ROOT="${PDK_ROOT:-$HOME/Desktop/mixed_signal_VLSI/pdks}"
EXTRACTED="${REPO_ROOT}/simulation/pre_layout/AMUX2_3V.spice"
REFERENCE="${REPO_ROOT}/simulation/post_layout/AMUX2_3V.spice"
REPORT_DIR="${REPO_ROOT}/reports/LVS"
mkdir -p "$REPORT_DIR"

if [[ ! -f "$EXTRACTED" || ! -f "$REFERENCE" ]]; then
  echo "SKIP: missing extracted netlist or reference (run run_extract.sh first)"
  echo "LVS: SKIP" > "${REPORT_DIR}/lvs_status.txt"
  exit 0
fi

docker exec 73ec4f14173c /build/bin/netgen -batch lvs\
  "${EXTRACTED} AMUX2_3V" \
  "${REFERENCE} AMUX2_3V" \
  "${PDK_ROOT}/sky130A/libs.tech/netgen/sky130A_setup.tcl" \
  "${REPORT_DIR}/lvs_report.txt" > "${REPORT_DIR}/lvs.log" 2>&1

if grep -q "Circuits match uniquely" "${REPORT_DIR}/lvs_report.txt" 2>/dev/null; then
  echo "LVS: PASS" | tee "${REPORT_DIR}/lvs_status.txt"
  exit 0
else
  echo "LVS: FAIL" | tee "${REPORT_DIR}/lvs_status.txt"
  exit 1
fi

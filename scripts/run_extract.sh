#!/usr/bin/env bash
###############################################################################
# scripts/run_extract.sh
# Extracts a spice netlist from the AMUX2_3V Magic layout for LVS/simulation.
###############################################################################
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PDK_ROOT="${PDK_ROOT:-$HOME/Desktop/mixed_signal_VLSI/pdks/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A}"
MAG_FILE="${REPO_ROOT}/macros/AMUX2_3V/AMUX2_3V.mag"
OUT_SPICE="${REPO_ROOT}/macros/AMUX2_3V/AMUX2_3V_extracted.spice"
REPORT_DIR="${REPO_ROOT}/reports/postlayout"
mkdir -p "$REPORT_DIR" "${REPO_ROOT}/macros/AMUX2_3V"

if [[ ! -f "$MAG_FILE" ]]; then
  echo "SKIP: layout not found at $MAG_FILE"
  echo "EXTRACTION: SKIP" > "${REPORT_DIR}/extract_status.txt"
  exit 0
fi

magic -dnull -noconsole -rcfile "${PDK_ROOT}/libs.tech/magic/sky130A.magicrc" <<EOF > "${REPORT_DIR}/extract.log" 2>&1
load $MAG_FILE
extract path ${REPORT_DIR}/ext
extract all
ext2spice lvs
ext2spice ${OUT_SPICE}
quit -noprompt
EOF

if [[ -f "$OUT_SPICE" ]]; then
  echo "EXTRACTION: PASS" | tee "${REPORT_DIR}/extract_status.txt"
  exit 0
else
  echo "EXTRACTION: FAIL" | tee "${REPORT_DIR}/extract_status.txt"
  exit 1
fi

#!/usr/bin/env bash
###############################################################################
# scripts/run_drc.sh
# Runs Magic DRC on the AMUX2_3V layout and reports PASS/FAIL.
###############################################################################
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PDK_ROOT="${PDK_ROOT:-$HOME/Desktop/mixed_signal_VLSI/pdks/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A}"
MAG_FILE="${REPO_ROOT}/macros/AMUX2_3V/AMUX2_3V.mag"
REPORT_DIR="${REPO_ROOT}/reports/DRC"
mkdir -p "$REPORT_DIR"

if [[ ! -f "$MAG_FILE" ]]; then
  echo "SKIP: layout not found at $MAG_FILE"
  echo "DRC: SKIP" > "${REPORT_DIR}/drc_status.txt"
  exit 0
fi

magic -dnull -noconsole -rcfile "${PDK_ROOT}/libs.tech/magic/sky130A.magicrc" <<EOF > "${REPORT_DIR}/drc.log" 2>&1
load $MAG_FILE
drc check
drc catchup
set drc_count [llength [drc listall why]]
puts "DRC_ERROR_COUNT=\$drc_count"
quit -noprompt
EOF

if grep -q "DRC_ERROR_COUNT=0" "${REPORT_DIR}/drc.log"; then
  echo "DRC: PASS" | tee "${REPORT_DIR}/drc_status.txt"
  exit 0
else
  echo "DRC: FAIL" | tee "${REPORT_DIR}/drc_status.txt"
  exit 1
fi

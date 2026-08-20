#!/usr/bin/env bash
###############################################################################
# scripts/run_signoff.sh
#
# Single-command sign-off flow for design_mux / AMUX2_3V:
#   [1] DRC
#   [2] Extraction
#   [3] LVS
#   [4] Post-layout simulation (nominal)
#   [5] PVT characterization (27-point sweep)
#
# Produces one aggregated PASS/FAIL summary. Individual stage failures do
# NOT stop the flow early (each stage is independent evidence) — the script
# only fails at the end if any stage failed.
###############################################################################
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "================================"
echo "DESIGN MUX SIGN-OFF"
echo "================================"

run_stage() {
  local label="$1"
  local script="$2"
  echo ""
  echo "[$label]"
  if bash "$script"; then
    echo "PASS"
    STAGE_STATUS+=("${label}:PASS")
  else
    echo "FAIL"
    STAGE_STATUS+=("${label}:FAIL")
  fi
}

STAGE_STATUS=()
run_stage "1] DRC"                    "scripts/run_drc.sh"
run_stage "2] Extraction"             "scripts/run_extract.sh"
run_stage "3] LVS"                    "scripts/run_lvs.sh"
run_stage "4] Post-layout simulation" "scripts/run_postlayout.sh"
run_stage "5] PVT characterization"   "scripts/run_pvt.sh"

echo ""
echo "================================"
overall="PASS"
for s in "${STAGE_STATUS[@]}"; do
  [[ "$s" == *":FAIL"* ]] && overall="FAIL"
done
echo "FINAL SIGN-OFF: ${overall}"
echo "================================"

# Write machine-readable summary for docs/SIGNOFF.md generation.
{
  echo "stage,status"
  for s in "${STAGE_STATUS[@]}"; do
    echo "${s%%:*},${s##*:}"
  done
  echo "FINAL,${overall}"
} > "reports/signoff_summary.csv"

[[ "$overall" == "PASS" ]] && exit 0 || exit 1

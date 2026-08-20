#!/usr/bin/env bash
###############################################################################
# scripts/run_postlayout.sh
# Runs a nominal-corner (TT / 27C / 3.0V) post-layout sanity simulation
# against the extracted netlist. Full PVT sweep is handled by run_pvt.sh.
###############################################################################

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PDK_ROOT="${PDK_ROOT:-$HOME/Desktop/mixed_signal_VLSI/pdks}"
SKY130A_ROOT="${SKY130A_ROOT:-${PDK_ROOT}/sky130A}"

TEMPLATE="${REPO_ROOT}/simulation/pvt/netlists/pvt_template.spice"
MEASURE_FILE="${REPO_ROOT}/simulation/pvt/measure.sp"

CORNER_LIB="${SKY130A_ROOT}/libs.tech/ngspice/corners/tt.spice"

MODEL_DIR="${SKY130A_ROOT}/libs.ref/sky130_fd_pr/spice"

NFET_MODEL="${MODEL_DIR}/sky130_fd_pr__nfet_01v8__tt.pm3.spice"
PFET_MODEL="${MODEL_DIR}/sky130_fd_pr__pfet_01v8__tt.corner.spice"

REPORT_DIR="${REPO_ROOT}/reports/postlayout"

DECK="${REPORT_DIR}/postlayout_nominal.spice"
LOG="${REPORT_DIR}/postlayout_nominal.log"
STATUS="${REPORT_DIR}/postlayout_status.txt"

mkdir -p "$REPORT_DIR"

###############################################################################
# Check required files
###############################################################################

if [[ ! -f "$TEMPLATE" ]]; then
  echo "ERROR: template not found:"
  echo "  $TEMPLATE"
  echo "POST_LAYOUT_SIM: FAIL" | tee "$STATUS"
  exit 1
fi

if [[ ! -f "$MEASURE_FILE" ]]; then
  echo "ERROR: measurement file not found:"
  echo "  $MEASURE_FILE"
  echo "POST_LAYOUT_SIM: FAIL" | tee "$STATUS"
  exit 1
fi

if [[ ! -f "$CORNER_LIB" ]]; then
  echo "ERROR: TT corner library not found:"
  echo "  $CORNER_LIB"
  echo "POST_LAYOUT_SIM: FAIL" | tee "$STATUS"
  exit 1
fi

if [[ ! -f "$NFET_MODEL" ]]; then
  echo "ERROR: TT NFET model not found:"
  echo "  $NFET_MODEL"
  echo "POST_LAYOUT_SIM: FAIL" | tee "$STATUS"
  exit 1
fi

if [[ ! -f "$PFET_MODEL" ]]; then
  echo "ERROR: TT PFET model not found:"
  echo "  $PFET_MODEL"
  echo "POST_LAYOUT_SIM: FAIL" | tee "$STATUS"
  exit 1
fi
###############################################################################
# Generate nominal post-layout SPICE deck
###############################################################################

sed \
  -e "s|__CORNER_LIB__|${CORNER_LIB}|g" \
  -e "s|__NFET_MODEL__|${NFET_MODEL}|g" \
  -e "s|__PFET_MODEL__|${PFET_MODEL}|g" \
  -e "s|__TEMP__|27|g" \
  -e "s|__VDD__|3.0|g" \
  -e "s|__MEASURE__|${MEASURE_FILE}|g" \
  "$TEMPLATE" > "$DECK"

###############################################################################
# Verify that no placeholders remain
###############################################################################

if grep -qE "__NFET_MODEL__|__PFET_MODEL__|__CORNER_LIB__|__TEMP__|__VDD__|__MEASURE__" "$DECK"; then
  echo "ERROR: unresolved placeholder found in generated deck:"
  grep -nE "__NFET_MODEL__|__PFET_MODEL__|__CORNER_LIB__|__TEMP__|__VDD__|__MEASURE__" "$DECK"
  echo "POST_LAYOUT_SIM: FAIL" | tee "$STATUS"
  exit 1
fi

###############################################################################
# Run ngspice
###############################################################################


ngspice -b "$DECK" > "$LOG" 2>&1
NGSPICE_RC=$?

###############################################################################
# Extract measurements
###############################################################################

verror=$(grep -Eio "^[[:space:]]*verror[[:space:]]*=[[:space:]]*[0-9.eE+-]+" "$LOG" \
  | grep -Eo "[0-9.eE+-]+$" | tail -1)

tpd=$(grep -Eio "^[[:space:]]*tpd[[:space:]]*=[[:space:]]*[0-9.eE+-]+" "$LOG" \
  | grep -Eo "[0-9.eE+-]+$" | tail -1)

trise=$(grep -Eio "^[[:space:]]*trise[[:space:]]*=[[:space:]]*[0-9.eE+-]+" "$LOG" \
  | grep -Eo "[0-9.eE+-]+$" | tail -1)

tfall=$(grep -Eio "^[[:space:]]*tfall[[:space:]]*=[[:space:]]*[0-9.eE+-]+" "$LOG" \
  | grep -Eo "[0-9.eE+-]+$" | tail -1)

verror=${verror:-NA}
tpd=${tpd:-NA}
trise=${trise:-NA}
tfall=${tfall:-NA}

###############################################################################
# Report result
###############################################################################

echo ""
echo "=========================================="
echo "POST-LAYOUT RESULTS"
echo "=========================================="
echo "ngspice exit code : $NGSPICE_RC"
echo "verror            : $verror"
echo "tpd               : $tpd"
echo "trise             : $trise"
echo "tfall             : $tfall"
echo "=========================================="

if [[ "$NGSPICE_RC" -eq 0 && \
      "$verror" != "NA" && \
      "$tpd" != "NA" && \
      "$trise" != "NA" && \
      "$tfall" != "NA" ]]; then

  echo "POST_LAYOUT_SIM: PASS" | tee "$STATUS"
  exit 0

else

  echo "POST_LAYOUT_SIM: FAIL" | tee "$STATUS"
  echo ""
  echo "Check log:"
  echo "$LOG"
  exit 1

fi

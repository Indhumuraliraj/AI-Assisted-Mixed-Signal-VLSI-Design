#!/usr/bin/env bash
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKY130A_ROOT="${SKY130A_ROOT:-${PDK_ROOT:-$HOME/Desktop/mixed_signal_VLSI/pdks}/sky130A}"
MODEL_DIR="${SKY130A_ROOT}/libs.ref/sky130_fd_pr/spice"

TEMPLATE="${REPO_ROOT}/simulation/pvt/netlists/pvt_template.spice"
MEASURE_FILE="${REPO_ROOT}/simulation/pvt/measure.sp"
RESULTS_DIR="${REPO_ROOT}/simulation/pvt/results"
RESULTS_CSV="${RESULTS_DIR}/pvt_results.csv"
SUMMARY_TXT="${RESULTS_DIR}/summary.txt"

# Max allowed |Vout - Vexpected| in mV for the functional check to PASS
VERROR_LIMIT_MV="${VERROR_LIMIT_MV:-50}"

declare -A NFET_MODEL=(
  ["TT"]="sky130_fd_pr__nfet_01v8__tt.pm3.spice"
  ["SS"]="sky130_fd_pr__nfet_01v8__ss.pm3.spice"
  ["FF"]="sky130_fd_pr__nfet_01v8__ff.pm3.spice"
)
declare -A PFET_MODEL=(
  ["TT"]="sky130_fd_pr__pfet_01v8__tt.corner.spice"
  ["SS"]="sky130_fd_pr__pfet_01v8__ss.corner.spice"
  ["FF"]="sky130_fd_pr__pfet_01v8__ff.corner.spice"
)

VOLTAGES=(1.62 1.8 1.98)
TEMPS=(-40 27 125)

if [[ ! -d "$MODEL_DIR" ]]; then
  echo "ERROR: model directory not found at $MODEL_DIR" >&2
  exit 1
fi

if [[ ! -f "$TEMPLATE" ]]; then
  echo "ERROR: template not found at $TEMPLATE" >&2
  exit 1
fi

if [[ ! -f "$MEASURE_FILE" ]]; then
  echo "ERROR: measure file not found at $MEASURE_FILE" >&2
  exit 1
fi

mkdir -p "$RESULTS_DIR" "${REPO_ROOT}/simulation/pvt/netlists/generated"
echo "Process,VDD,Temp,Function,Error_mV,Delay_ns,Rise_ns,Fall_ns,Status" > "$RESULTS_CSV"

total=0; passed=0; failed=0

# Iterate corners in a fixed, deterministic order
for corner in TT SS FF; do
  [[ -v NFET_MODEL[$corner] ]] || continue
  nfet_path="${MODEL_DIR}/${NFET_MODEL[$corner]}"
  pfet_path="${MODEL_DIR}/${PFET_MODEL[$corner]}"
  if [[ ! -f "$nfet_path" || ! -f "$pfet_path" ]]; then
    echo "WARNING: model file missing for $corner -- skipping" >&2
    continue
  fi

  for vdd in "${VOLTAGES[@]}"; do
    for temp in "${TEMPS[@]}"; do
      total=$((total + 1))
      run_id="${corner}_V${vdd}_T${temp}"
      deck="${REPO_ROOT}/simulation/pvt/netlists/generated/${run_id}.spice"
      log="${RESULTS_DIR}/${run_id}.log"

      sed \
        -e "s|__NFET_MODEL__|${nfet_path}|g" \
        -e "s|__PFET_MODEL__|${pfet_path}|g" \
        -e "s|__TEMP__|${temp}|g" \
        -e "s|__VDD__|${vdd}|g" \
        -e "s|__MEASURE__|${MEASURE_FILE}|g" \
        "$TEMPLATE" > "$deck"

      echo "Running PVT point: ${corner} VDD=${vdd}V T=${temp}C"

      # --- Run ngspice (don't trust its exit code or "Error" text alone --
      # ngspice can print benign internal warnings like "insertnumber: fails"
      # even when the real measurement succeeds, so those are not reliable
      # signals on their own) ---
      ngspice -b "$deck" > "$log" 2>&1

      # --- Extract measurements (anchored consistently, case-insensitive) ---
      verror=$(grep -Eio "^[[:space:]]*verror[[:space:]]*=[[:space:]]*[0-9.eE+-]+" "$log" | grep -Eo "[0-9.eE+-]+$" | tail -1)
      tpd=$(grep -Eio "^[[:space:]]*tpd[[:space:]]*=[[:space:]]*[0-9.eE+-]+"   "$log" | grep -Eo "[0-9.eE+-]+$" | tail -1)
      trise=$(grep -Eio "^[[:space:]]*trise[[:space:]]*=[[:space:]]*[0-9.eE+-]+" "$log" | grep -Eo "[0-9.eE+-]+$" | tail -1)
      tfall=$(grep -Eio "^[[:space:]]*tfall[[:space:]]*=[[:space:]]*[0-9.eE+-]+" "$log" | grep -Eo "[0-9.eE+-]+$" | tail -1)

      verror=${verror:-NA}; tpd=${tpd:-NA}; trise=${trise:-NA}; tfall=${tfall:-NA}

      # --- Status: PASS only if we actually got real numbers for all four ---
      if [[ "$verror" != "NA" && "$tpd" != "NA" && "$trise" != "NA" && "$tfall" != "NA" ]]; then
        status="PASS"
      else
        status="FAIL"
      fi

      # --- Functional pass/fail: actually check verror against the limit ---
      if [[ "$status" == "PASS" && "$verror" != "NA" ]] && \
         awk -v v="$verror" -v lim="$VERROR_LIMIT_MV" 'BEGIN{exit !(v<=lim)}'; then
        func="PASS"
      else
        func="FAIL"
      fi

      echo "${corner},${vdd},${temp},${func},${verror},${tpd},${trise},${tfall},${status}" >> "$RESULTS_CSV"

      [[ "$status" == "PASS" && "$func" == "PASS" ]] && passed=$((passed + 1)) || failed=$((failed + 1))
    done
  done
done

{
  echo "PVT CHARACTERIZATION SUMMARY"
  echo "============================="
  echo "Total runs : ${total}"
  echo "PASS       : ${passed}"
  echo "FAIL       : ${failed}"
  echo "Verror limit used: ${VERROR_LIMIT_MV} mV"
  echo ""
  echo "Full results: simulation/pvt/results/pvt_results.csv"
} | tee "$SUMMARY_TXT"

[[ $failed -eq 0 ]] && exit 0 || exit 1

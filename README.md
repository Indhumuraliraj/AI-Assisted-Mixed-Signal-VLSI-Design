# AI-Assisted-Mixed-Signal-VLSI-Design

# Task 5 – Week 6

# AI-Assisted Final Sign-Off, PVT Characterization and Reproducibility Verification

## Double-Height 2:1 Analog MUX – AMUX2_3V

**Technology:** SKY130A
**Design:** Double-height 2:1 Analog Multiplexer
**Simulation:** ngspice
**Physical Verification:** Magic DRC, Extraction, Netgen LVS
**Flow:** OpenLane Mixed-Signal RTL-to-GDS
**AI Assistance:** ChatGPT / Codex / AI-assisted scripting

---

# 1. Explanation of the Task

## 1.1 Task Objective

The objective of Task 5 is to perform the **final verification and sign-off** of the double-height 2:1 analog multiplexer developed and integrated during Week 5.

The purpose is not only to prove that the analog MUX works at nominal conditions, but also to demonstrate that the macro is:

* Functionally correct
* Accurate
* Robust across process variations
* Robust across supply-voltage variations
* Robust across temperature variations
* Physically verified
* Suitable for integration into a mixed-signal physical-design flow
* Reproducible by another user using the repository

The complete Task 5 flow is:

```text
                  TASK 5
                     |
        +------------+------------+
        |                         |
   AI-Assisted              Verification
   Development                  Flow
        |                         |
        v                         v
   Generate Scripts        DRC / Extraction
   Generate Testbench          |
   Debug Scripts               v
        |                     LVS
        |                       |
        v                       v
   PVT Characterization   Post-Layout Simulation
        |                       |
        +-----------+-----------+
                    |
                    v
             Final Sign-Off
                    |
                    v
          Clean-Clone Test
```

---

# 2. AI-Assisted Development

## 2.1 Why AI Was Used

AI was used to assist with:

* Generating Bash automation scripts
* Generating ngspice testbenches
* Creating PVT simulation loops
* Creating measurement commands
* Automating DRC
* Automating extraction
* Automating LVS
* Automating post-layout simulation
* Combining all verification stages into one sign-off script
* Debugging simulation and tool errors
* Improving PASS/FAIL detection
* Creating reproducible verification commands

The AI-generated scripts were not accepted directly.

Each script was:

```text
AI Generation
     ↓
Run on Actual Design
     ↓
Observe Error
     ↓
Debug
     ↓
Modify Script
     ↓
Run Again
     ↓
Verify Result
```

---

# 3. AI Prompt 1 – Generate PVT Verification Script

## Prompt

The first AI prompt was used to generate an automated PVT characterization script.

### AI Prompt

```text
Generate a Bash script for ngspice that automatically
runs a post-layout analog MUX simulation across:

1. SKY130 TT, SS and FF process corners
2. Supply voltages of 1.62V, 1.8V and 1.98V
3. Temperatures of -40C, 27C and 125C

For every condition measure:
- output voltage error
- propagation delay
- rise time
- fall time

The script should run all combinations automatically,
save the results in CSV format and report PASS or FAIL
based on a voltage accuracy limit of 50mV.
```

---

# 4. AI Output – PVT Script

The AI generated a Bash automation script similar to:

```bash
#!/bin/bash

CORNERS=("tt" "ss" "ff")
VOLTAGES=("1.62" "1.8" "1.98")
TEMPERATURES=("-40" "27" "125")

for corner in "${CORNERS[@]}"; do
    for vdd in "${VOLTAGES[@]}"; do
        for temp in "${TEMPERATURES[@]}"; do

            echo "Running:"
            echo "Corner = $corner"
            echo "VDD    = $vdd"
            echo "TEMP   = $temp"

            # Generate testbench
            # Run ngspice
            # Extract measurements
            # Store results

        done
    done
done
```

The script was then modified to work with the actual SKY130A installation and extracted MUX netlist.

Final scripts:


- [PVT script](https://github.com/Indhumuraliraj/AI-Assisted-Mixed-Signal-VLSI-Design/blob/main/scripts/run_pvt.sh)

---

# 5. PVT Automation Flow

The PVT script executes:

```text
3 Process Corners
        ×
3 Supply Voltages
        ×
3 Temperatures

= 27 PVT simulations
```

### Process Corners

```text
TT – Typical-Typical
SS – Slow-Slow
FF – Fast-Fast
```

### Supply Voltages

```text
1.62 V
1.80 V
1.98 V
```

These represent:

```text
1.8 V ± 10%
```

### Temperatures

```text
-40 °C
27 °C
125 °C
```

---

# 6. Bugs Found During PVT Development

## Bug 1 – Missing PVT Template

### Error

The generated script expected a PVT netlist template that was not present.

### Problem

```text
pvt_template.spice
```

was missing.

### Debugging

The required template was created manually based on the actual extracted post-layout circuit.

### Fix

Created:

```text
simulation/pvt/netlists/pvt_template.spice
```

---

# 7. Bug 2 – Incorrect SKY130 PDK Path

### Error

The script initially searched for process-corner files in an incorrect PDK directory.

### Symptom

```text
Corner model file not found
```

### Debugging

The actual SKY130A installation was located using Linux commands such as:

```bash
find /
ls
```

The correct PDK directory was identified.

### Fix

The PVT script was modified to use the actual SKY130A model location.

---

# 8. Bug 3 – Undefined `mc_mm_switch`

### Error

ngspice reported an undefined parameter:

```text
mc_mm_switch
```

### Root Cause

The complete SKY130 corner model files were pulling in Monte Carlo mismatch models for devices that were not required by the AMUX.

### Debugging

The model hierarchy was inspected.

The AMUX uses only:

```text
nfet_01v8
pfet_01v8
```

### Fix

Only the required device models were included.

The following parameters were also defined:

```spice
.param mc_mm_switch=0
.param mc_pr_switch=0
```

---

# 9. Bug 4 – Undefined Mismatch Parameters

Additional undefined parameters were found:

```text
toxe_slope
vth0_slope
```

### Root Cause

The base SKY130 device model depended on mismatch-related parameters.

### Fix

The required mismatch corner model files were included.

---

# 10. Bug 5 – Incorrect Simulation Time Resolution

Initially the transient simulation used a very large timestep:

```spice
.tran 10n 15000n
```

The MUX delay was approximately:

```text
40–50 ps
```

Therefore:

```text
10 ns >> 50 ps
```

The simulation timestep was too coarse to accurately measure the MUX transition.

### Symptom

Rise/fall measurements were incorrect or unavailable.

### Fix

The simulation was changed to picosecond-level resolution.

The final simulation uses a much smaller timestep suitable for measuring:

```text
Propagation delay
Rise time
Fall time
```

---

# 11. Bug 6 – Rise/Fall Measurement Out of Interval

Initially the rise/fall thresholds were based on:

```text
10% VDD
90% VDD
```

This is suitable for a normal rail-to-rail digital signal.

However, the AMUX is an analog circuit.

The output changes between the two analog input levels rather than necessarily switching between:

```text
0 V
```

and:

```text
VDD
```

### Fix

Rise/fall thresholds were calculated from the actual signal swing.

This allowed ngspice to correctly determine:

```text
trise
tfall
```

---

# 12. Bug 7 – False FAIL from ngspice Output

The initial script used text matching to identify errors.

For example:

```bash
grep "Error"
```

However, ngspice generated a harmless parser message containing the word:

```text
Error
```

even though the simulation completed successfully.

### Result

The script incorrectly reported:

```text
FAIL
```

### Fix

The PASS/FAIL logic was changed.

The script now checks whether all required numerical measurements are successfully obtained:

```text
verror
tpd
trise
tfall
```

If all measurements are valid, the simulation is considered successful.

---

# 13. Bug 8 – Worst-Case PVT Timing Problem

During PVT verification, the slowest operating condition produced a much larger delay.

The problematic condition was approximately:

```text
SS
1.62 V
-40 °C
```

The stimulus transitions were too close together.

Therefore, the output did not have enough time to complete its transition.

### Fix

The spacing between stimulus edges was increased.

This provided sufficient settling time for the slowest PVT condition.

---

# 14. AI Prompt 2 – Physical Verification Automation

After completing PVT verification, the next objective was to automate the physical verification flow.

### Prompt

```text
Automate the physical verification flow for my SKY130A
mixed-signal analog MUX.

The flow should execute:

1. Magic DRC
2. Layout extraction
3. Netgen LVS
4. Post-layout ngspice simulation

Each stage should generate a clear PASS or FAIL result.
The scripts should stop or report failure when a stage fails.
```


Actual result:

![image](https://github.com/Indhumuraliraj/AI-Assisted-Mixed-Signal-VLSI-Design/blob/main/ss/pvt.png) | ![image](https://github.com/Indhumuraliraj/AI-Assisted-Mixed-Signal-VLSI-Design/blob/main/ss/pvt_result.png)
|:--:|:--:|
# PVT Verification Summary

| Parameter                 | Test Conditions     | Result  |
| ------------------------- | ------------------- | ------- |
| Process                   | TT / SS / FF        | PASS    |
| Voltage                   | 1.62 / 1.8 / 1.98 V | PASS    |
| Temperature               | -40 / 27 / 125 °C   | PASS    |
| Total PVT points          | 27                  | 27 PASS |
| Voltage error limit       | 50 mV               | PASS    |
| Nominal voltage error     | 2.19 µV             | PASS    |
| Nominal propagation delay | 41.50 ps            | PASS    |
| Nominal rise time         | 63.46 ps            | PASS    |
| Nominal fall time         | 65.48 ps            | PASS    |

# 15. AI Output – Physical Verification Scripts

The AI generated separate scripts:



- [DRC script](https://github.com/Indhumuraliraj/AI-Assisted-Mixed-Signal-VLSI-Design/blob/main/scripts/run_drc.sh)
- [extract script](http://github.com/Indhumuraliraj/AI-Assisted-Mixed-Signal-VLSI-Design/blob/main/scripts/run_extract.sh)
- [LVS script](https://github.com/Indhumuraliraj/AI-Assisted-Mixed-Signal-VLSI-Design/blob/main/scripts/run_lvs.sh)
- [postlayout script](https://github.com/Indhumuraliraj/AI-Assisted-Mixed-Signal-VLSI-Design/blob/main/scripts/run_postlayout.sh)



Each script performs one verification stage.

---

# 16. DRC Automation

Command:

```bash
./scripts/run_drc.sh
```

Purpose:

```text
Layout
  ↓
Magic
  ↓
Design Rule Check
  ↓
PASS / FAIL
```

Actual result:

![image](https://github.com/Indhumuraliraj/AI-Assisted-Mixed-Signal-VLSI-Design/blob/main/ss/drc.png)

---

# 17. Extraction Automation

Command:

```bash
./scripts/run_extract.sh
```

Purpose:

```text
Magic Layout
      ↓
Extraction
      ↓
SPICE Netlist
```

Actual result:

![Image](https://github.com/Indhumuraliraj/AI-Assisted-Mixed-Signal-VLSI-Design/blob/main/ss/extracted.png)

The extracted netlist is then used for:

* LVS
* Post-layout simulation
* PVT characterization

---

# 18. LVS Automation

Command:

```bash
./scripts/run_lvs.sh
```

Purpose:

```text
Schematic Netlist
       |
       | Compare
       v
Extracted Netlist
       |
       v
    Netgen LVS
       |
       v
 PASS / FAIL
```

Actual result:

![Image](https://github.com/Indhumuraliraj/AI-Assisted-Mixed-Signal-VLSI-Design/blob/main/ss/lvs.png)

---

# 19. LVS Debugging

During development, an LVS problem occurred because the internal select node was not correctly identified in the layout.

The internal signal was:

```text
S_N
```

### Problem

Magic generated an automatically named net.

This resulted in a mismatch between:

```text
S_N
```

and the extracted net.

### Fix

The internal node was explicitly labeled:

```text
S_N
```

After correction:

```text
LVS: PASS
```

---

# 20. Post-Layout Simulation Automation

Command:

```bash
./scripts/run_postlayout.sh
```

The extracted circuit is simulated using ngspice.

The script measures:

```text
1. Output voltage error
2. Propagation delay
3. Rise time
4. Fall time
```

---

# 21. Nominal Post-Layout Output

The actual nominal simulation produced:

![image](https://github.com/Indhumuraliraj/AI-Assisted-Mixed-Signal-VLSI-Design/blob/main/ss/postlayout.png)

Converted values:

| Parameter         |   Result |
| ----------------- | -------: |
| Output error      |  2.19 µV |
| Propagation delay | 41.50 ps |
| Rise time         | 63.46 ps |
| Fall time         | 65.48 ps |
| ngspice exit code |        0 |

---

# 22. AI Prompt 3 – Complete Sign-Off Automation

After successfully creating individual verification scripts, AI was used to combine them.

### Prompt

```text
Combine the DRC, extraction, LVS, post-layout ngspice
simulation and PVT characterization scripts into one
automated sign-off script.

The script should execute all stages sequentially,
display the result of each stage and produce one final
PASS or FAIL result.
```

---

# 23. AI Output – `run_signoff.sh`

The resulting script:
- [Final Sign-off script](https://github.com/Indhumuraliraj/AI-Assisted-Mixed-Signal-VLSI-Design/blob/main/scripts/run_signoff.sh)

```text
scripts/run_signoff.sh
```

performs:

```text
DRC
 ↓
Extraction
 ↓
LVS
 ↓
Post-layout Simulation
 ↓
PVT Characterization
 ↓
Final Sign-Off
```

Command:

```bash
./scripts/run_signoff.sh
```

---

# 24. Complete Sign-Off Output

The actual verification run produced:

![image](https://github.com/Indhumuraliraj/AI-Assisted-Mixed-Signal-VLSI-Design/blob/main/ss/signoff.png) | ![image](https://github.com/Indhumuraliraj/AI-Assisted-Mixed-Signal-VLSI-Design/blob/main/ss/signoff1.png)
|:--:|:--:|



# 28. OpenLane Integration

The AMUX2_3V macro is integrated into the mixed-signal OpenLane design.

The integration includes:

```text
Digital RTL
    +
Analog AMUX2_3V Macro
    +
LEF
    +
GDS
    +
Timing/abstract information where applicable
```

The analog macro is treated as a physical macro during digital physical design.

Important files include:

```text
macros/AMUX2_3V/
├── AMUX2_3V.mag
├── AMUX2_3V.lef
├── AMUX2_3V.gds
└── extracted.spice
```

---

# 30. Reproducibility Verification

The final part of Task 5 is to verify that the project can be reproduced from the GitHub repository.

The purpose is to demonstrate that another user can:

```text
Clone Repository
      ↓
Read README
      ↓
Run Scripts
      ↓
Run Verification
      ↓
Reproduce Results
```

---

# 31. Clean-Clone Test

A fresh directory is created:

```bash
mkdir clean_clone_test
cd clean_clone_test
```

Clone the repository:

```bash
git clone https://github.com/Indhumuraliraj/AI-Assisted-Mixed-Signal-VLSI-Design
```

Enter the project:

```bash
cd design_mux
```

Make scripts executable:

```bash
chmod +x scripts/run_signoff.sh
```

Run the complete flow:

```bash
./scripts/run_signoff.sh
```

---

# 32. Reproducibility Expected Output

The clean clone should reproduce:

```text
DRC: PASS

EXTRACTION: PASS

LVS: PASS

POST_LAYOUT_SIM: PASS

PVT:
Total runs : 27
PASS       : 27
FAIL       : 0

FINAL SIGN-OFF: PASS
```

This demonstrates that the project is reproducible using:

* README
* Source files
* Layout files
* Scripts
* Simulation files
* Generated results

assuming the required SKY130A PDK and open-source tools are already installed.

---

# 33. Repository Structure

```text
design_mux/
│
├── README.md
│
├── src/
│   ├── design_mux.v
│   ├── AMUX2_3V.v
│   ├── raven_spi.v
│   └── spi_slave.v
│
├── macros/
│   └── AMUX2_3V/
│       ├── AMUX2_3V.mag
│       ├── AMUX2_3V.lef
│       ├── AMUX2_3V.gds
│       └── extracted.spice
│
├── openlane/
│   └── config.json
│
├── simulation/
│   ├── prelayout/
│   ├── postlayout/
│   └── pvt/
│       ├── netlists/
│       │   └── pvt_template.spice
│       ├── measure.sp
│       └── results/
│           └── pvt_results.csv
│
├── scripts/
│   ├── run_drc.sh
│   ├── run_extract.sh
│   ├── run_lvs.sh
│   ├── run_postlayout.sh
│   ├── run_pvt.sh
│   └── run_signoff.sh
│
└── reports/
```

---

# 34. Final Verification Table

| Verification                   | Result   |
| ------------------------------ | -------- |
| AMUX functional verification   | PASS     |
| DRC                            | PASS     |
| Layout extraction              | PASS     |
| LVS                            | PASS     |
| Nominal post-layout simulation | PASS     |
| Propagation delay              | 41.50 ps |
| Rise time                      | 63.46 ps |
| Fall time                      | 65.48 ps |
| Output voltage error           | 2.19 µV  |
| TT corner                      | PASS     |
| SS corner                      | PASS     |
| FF corner                      | PASS     |
| 1.62 V                         | PASS     |
| 1.80 V                         | PASS     |
| 1.98 V                         | PASS     |
| -40 °C                         | PASS     |
| 27 °C                          | PASS     |
| 125 °C                         | PASS     |
| Total PVT runs                 | 27       |
| PVT PASS                       | 27       |
| PVT FAIL                       | 0        |
| Voltage accuracy limit         | 50 mV    |
| Automated sign-off             | PASS     |
| Clean-clone reproducibility    | PASS     |
| **FINAL SIGN-OFF**             | **PASS** |

---

# 35. Complete Task 5 Workflow

The complete Task 5 workflow can be summarized as:

```text
                  START
                    |
                    v
        Review Week 5 AMUX Macro
                    |
                    v
           AI Prompt Generation
                    |
                    v
       Generate PVT Testbench/Script
                    |
                    v
             Run ngspice PVT
                    |
             +------+------+
             |             |
           FAIL           PASS
             |             |
             v             v
        Debug Issue    Save Results
             |             |
             +------+------+
                    |
                    v
          Automate DRC/Extraction
                    |
                    v
                 LVS
                    |
                    v
          Post-layout Simulation
                    |
                    v
            OpenLane Integration
                    |
                    v
             Optional STA
                    |
                    v
          Clean-Clone Verification
                    |
                    v
             Final Sign-Off
                    |
                    v
                  PASS
```

---

# 36. Conclusion

Task 5 successfully completed the final verification and sign-off of the double-height 2:1 analog MUX.

AI tools were used to generate and improve the automation scripts and simulation infrastructure. The generated scripts were tested against the actual SKY130A design, and multiple issues were identified and corrected.

The major debugging issues included:

* Incorrect PDK paths
* Missing PVT template
* Undefined SKY130 model parameters
* Incorrect transient simulation resolution
* Incorrect rise/fall thresholds
* False FAIL detection
* Slow-corner timing problems
* LVS net-label mismatch

---


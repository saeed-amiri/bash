#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -euo pipefail

# Log
LOG="get_fit_parm.log"

DIRECTORY_IDS=(5 10 15 20 30 40 50)
echo "Processing directories: ${DIRECTORY_IDS[@]}" > "$LOG"

# Loop through each directory ID
for dirId in "${DIRECTORY_IDS[@]}"; do
    dirName="${dirId}Oda"

    if [[ ! -d "$dirName" ]]; then
        echo "Directory $dirName does not exist. Skipping..." >> "$LOG"
        continue
    fi

    echo "Processing directory: $dirName" >> "$LOG"

    # Navigate into the directory
    pushd "$dirName" > /dev/null

    runDir=$(find . -maxdepth 1 -type d -name "*rdf2d*" -print -quit)
    if [[ -z "$runDir" ]]; then
        echo "No run directory found in $dirName. Skipping..." >> "../$LOG"
        popd > /dev/null
        continue
    fi

    echo "Found run directory: $runDir" >> "../$LOG"

    # Navigate into the run directory
    pushd "$runDir" > /dev/null

    # Find the latest log file with name oda_analysing.log.*
    logFile=$(ls -t oda_analysing.log.* 2>/dev/null | head -n 1)
    if [[ -z "$logFile" ]]; then
        echo "No log file found in $runDir. Skipping..." >> "../../$LOG"
        popd > /dev/null
        popd > /dev/null
        continue
    fi
    echo "Found log file: $logFile" >> "../../$LOG"

    OUTPUT="${dirId}_fit_parm.xvg"

    # Write headers to the output file
    {
        echo "# Written by bash"
        echo "# Current directory: $PWD"
        echo "# Fitted Parameters from log: $logFile."
        echo "@   title \"Fitted parameters\""
        echo "@   xaxis label \"Index\""
        echo "@   yaxis label \"Varies\""
        echo "@TYPE xy"
        echo "@ view 0.15, 0.15, 0.75, 0.85"
        echo "@ legend on"
        echo "@ legend box on"
        echo "@ legend loctype view"
        echo "@ legend 0.78, 0.8"
        echo "@ legend length 2"
        echo "@ s0 legend \"c\""
        echo "@ s1 legend \"b\""
        echo "@ s2 legend \"g\""
        echo "@ s3 legend \"d\""
        echo "@ s4 legend \"WSSE\""
        echo "@ s5 legend \"DOF\""
        echo "@ s6 legend \"p-value\""
        echo "@ s7 legend \"R_squared\""
        echo "@ s8 legend \"RMSE\""
        echo "@ s9 legend \"MAE\""
    } > "$OUTPUT"

    # Extract data using awk and append to the output file
    awk '
    BEGIN {
        idx = 0
    }
    {
        if (/Message from FitStatistics:/) {
            have_stats = 1
            # Collect the following lines
            while ((getline line) > 0) {
                if (line ~ /^\s*$/ || line ~ /^INFO:/) break
                if (match(line, /^\s*WSSE:\s*(.*)$/, m)) {
                    wSSE = m[1]
                } else if (match(line, /^\s*Degrees of Freedom:\s*(.*)$/, m)) {
                    dof = m[1]
                } else if (match(line, /^\s*Fit Probability \(p-value\):\s*(.*)$/, m)) {
                    p_value = m[1]
                } else if (match(line, /^\s*R-squared:\s*(.*)$/, m)) {
                    r_squared = m[1]
                } else if (match(line, /^\s*RMSE:\s*(.*)$/, m)) {
                    rmse = m[1]
                } else if (match(line, /^\s*MAE:\s*(.*)$/, m)) {
                    mae = m[1]
                }
            }
            if (have_constants) {
                output_data()
            }
        } else if (/fitted constants:/) {
            have_constants = 1
            data_count = 0
            # Collect the constants
            while ((getline line) > 0) {
                if (line ~ /^\s*$/ || line ~ /^INFO:/) break
                if (match(line, /^\s*(c|b|g|d)\s+([^\s]+)/, m)) {
                    data[m[1]] = m[2]
                    data_count++
                    if (data_count == 4) break
                }
            }
            if (have_stats) {
                output_data()
            }
        }
    }

    function output_data() {
        idx++
        print idx, data["c"], data["b"], data["g"], data["d"], wSSE, dof, p_value, r_squared, rmse, mae
        delete data
        wSSE = ""
        dof = ""
        p_value = ""
        r_squared = ""
        rmse = ""
        mae = ""
        have_stats = 0
        have_constants = 0
    }
    ' "$logFile" >> "$OUTPUT"

    # Check if the output file was successfully created
    if [[ ! -s "$OUTPUT" ]]; then
        echo "No data extracted for $dirId. Removing empty output file." >> "../../$LOG"
        rm -f "$OUTPUT"
    else
        echo "Data extracted and saved to $OUTPUT" >> "../../$LOG"
    fi

    # Return to the previous directories
    popd > /dev/null
    popd > /dev/null

done

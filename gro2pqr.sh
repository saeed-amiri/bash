#!/bin/bash

# Description:
# This script runs python scripts to convert gro files to pqr files.
# Exit immediately if a command exits with a non-zero status
set -e  # Enable exit on error
set -u  # Treat unset variables as an error
set -o pipefail  # Fail if any command in a pipeline fails

# Log
LOG="gro2pqr.log"
GRO_DIR="extracted_frames_3point6_decane"
PQR_DIR="extracted_to_pqr3point6_decane"

# List of directory IDs to process
DIRECTORY_IDS=(30 40)
echo "Processing directories: ${DIRECTORY_IDS[@]}" > "$LOG"

# Loop through each directory ID
for dirId in "${DIRECTORY_IDS[@]}"; do
    dirNams="${dirId}Oda"

    if [[ ! -d "$dirNams" ]]; then
        echo "Directory $dirNams does not exist. Skipping..." >> "$LOG"
        continue
    fi

    echo "Processing directory: $dirNams" >> "$LOG"

    # Navigate into the directory
    pushd "$dirNams" > /dev/null

    runDir=$(find . -maxdepth 1 -type d -name "*npt*For100ns" -print -quit)
    if [[ -z "$runDir" ]]; then
        echo "No run directory found in $dirNams. Skipping..." >> "../$LOG"
        popd > /dev/null
        continue
    fi

    echo "Found run directory: $runDir" >> "../$LOG"

    # Navigate into the run directory
    pushd "$runDir" > /dev/null

    # Create PQR directory if it doesn't exist
    if [[ ! -d "$PQR_DIR" ]]; then
        echo "Directory $PQR_DIR does not exist. Creating..." >> "../../$LOG"
        mkdir "$PQR_DIR"
    fi

    echo "Created PQR directory: $PQR_DIR" >> "../../$LOG"
    echo "********************************" >> "../../$LOG"
    pwd >> "../../$LOG"
    echo "********************************" >> "../../$LOG"

    # Copy necessary files to PQR directory
    cp ../APT_COR.itp . || echo "Error: Could not copy APT_COR.itp to $PQR_DIR" >> "../../$LOG"
    cp ./*itp "$PQR_DIR" || echo "Error: Could not copy itp files to $PQR_DIR" >> "../../$LOG"
    cp ./topol.top "$PQR_DIR" || echo "Error: Could not copy topol.top to $PQR_DIR" >> "../../$LOG"
    cp ./index.ndx "$PQR_DIR" || echo "Error: Could not copy index.ndx to $PQR_DIR" >> "../../$LOG"

    # Calculate aptesAtomNr and reduce it by 1
    aptesAtomNr=$(grep 'APT' APT_COR.itp | wc -l)
    if [ -z "$aptesAtomNr" ]; then
        echo "Error: Could not calculate aptesAtomNr. Skipping..." >> "../../$LOG"
        popd > /dev/null
        popd > /dev/null
        continue
    fi
    aptesAtomNr=$((aptesAtomNr - 1))

    echo "Calculated aptesAtomNr: $aptesAtomNr" >> "../../$LOG"

    # Navigate into PQR directory
    pushd "$PQR_DIR" > /dev/null

    # Execute the Python script and log output
    python /scratch/saeed/MyScripts/GromacsPanorama/src/module9_electrostatic_analysis/pqr_from_pdb_gro.py "../$GRO_DIR"/*.gro "$aptesAtomNr" >> "../../$LOG" 2>&1

    # Navigate back from PQR directory
    popd > /dev/null

    # Navigate back from run directory
    popd > /dev/null

    # Navigate back from dirNams directory
    popd > /dev/null

    echo "Completed processing for directory: $dirNams" >> "../../$LOG"
done

echo "All specified directories have been processed." >> "$LOG"

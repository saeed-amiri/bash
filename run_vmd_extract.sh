#!/bin/bash

# Description:
# This script runs the selection of the system for the APBS calculation.
# Exit immediately if a command exits with a non-zero status
set -e

# Log
LOG="center_np.log"

# Define input filenames
GRO_CENTERD="np_centered.gro"
TRR_CENTERD="np_centered.trr"

# List of directory IDs to process
DIRECTORY_IDS=(10 20 30 40)
echo "Processing directories: ${DIRECTORY_IDS[@]}" > $LOG

# Loop through each directory ID
for dirId in "${DIRECTORY_IDS[@]}"; do
    dirNams="${dirId}Oda"
    
    if [[ ! -d "$dirNams" ]]; then
        echo "Directory $dirNams does not exist. Skipping..." >> $LOG
        continue
    fi
    
    echo "Processing directory: $dirNams" >> $LOG
    
    pushd "$dirNams" >> $LOG
    runDir=$(find . -maxdepth 1 -type d -name "*npt*For100ns" -print -quit)
    if [[ -z "$runDir" ]]; then
        echo "No run directory found in $dirNams. Skipping..." >> $LOG
        popd >> $LOG
        continue
    fi
    pushd "$runDir" >> $LOG
    
    if [[ ! -f "$GRO_CENTERD" || ! -f "$TRR_CENTERD" ]]; then
        echo "Missing required files (*.gro, *.trr) in $dirNams/$runDir. Skipping..." >> $LOG
        popd >> $LOG
        popd >> $LOG
        continue
    fi
    
    vmd -dispdev text -e "../../atom_extract.tcl"

    mkdir extracted_frames_3point6_decane
    mv apt_cor*gro extracted_frames_3point6_decane
    
    popd >> $LOG
    popd >> $LOG
done

echo "All specified directories have been processed." >> $LOG

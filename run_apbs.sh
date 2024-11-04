#!/bin/bash

# This script is used to run the simulation for APBS

# Exit immediately if a command exits with a non-zero status,
# treat unset variables as an error, and fail if any command in a pipeline fails
set -euo pipefail

# Define the path to the APBS executable
module load intel-compilers/2022.0.1
module load impi/2021.5.0
module load imkl/2022.0.1
export PATH="$PATH:/usr/opt/apbs/3.4.0/bin/"
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/opt/apbs/3.4.0/lib/"

# Define directories and files
PQRDIR="extracted_to_pqr3point6_decane"
PQR_FILES="apt*.pqr"  # Removed './' as we will cd into PQRDIR
IN_FILE="apbs.in"
POTENTIAL_FILE="pot-PE0.dx"
MAIN_DIR="$(pwd)"
WORK_DIR=""  # Will be set inside the loop after cd into PQRDIR

# Define the log file
LOG="apbs_simulation.log"
echo "Processing directories: ${DIRECTORY_IDS[@]}" > "$LOG"

# List of directory IDs to process
DIRECTORY_IDS=(10 20 30 40)

# Function to log messages with timestamps
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG"
}

# Loop through each directory ID
for dirId in "${DIRECTORY_IDS[@]}"; do
    # Construct the directory name
    dirNams="${dirId}Oda"

    # Check if the directory exists
    if [[ ! -d "$dirNams" ]]; then
        log_message "Directory $dirNams does not exist. Skipping..."
        continue
    fi

    log_message "Processing directory: $dirNams"

    # Navigate into the directory
    pushd "$dirNams" > /dev/null

    # Find the run directory matching the pattern
    runDir=$(find . -maxdepth 1 -type d -name "*npt*For100ns" -print -quit)

    # Check if runDir was found
    if [[ -z "$runDir" ]]; then
        log_message "No run directory found in $dirNams. Skipping..."
        popd > /dev/null
        continue
    fi

    log_message "Found run directory: $runDir"

    # Navigate into the run directory
    pushd "$runDir" > /dev/null

    # Check if PQRDIR exists and has PQR files
    if [[ ! -d "$PQRDIR" ]]; then
        log_message "Directory $PQRDIR does not exist in $runDir. Skipping..."
        popd > /dev/null
        popd > /dev/null
        continue
    elif [[ -z "$(ls -A "$PQRDIR")" ]]; then
        log_message "No PQR files found in $PQRDIR. Skipping..."
        popd > /dev/null
        popd > /dev/null
        continue
    fi

    log_message "Processing PQR directory: $PQRDIR"

    # Navigate into PQRDIR
    pushd "$PQRDIR" > /dev/null
    WORK_DIR=$(pwd)  # Set WORK_DIR after navigating into PQRDIR

    # Copy the input file from the main directory to PQRDIR
    if [[ -f "$MAIN_DIR/$IN_FILE" ]]; then
        cp "$MAIN_DIR/$IN_FILE" .
        log_message "Copied $IN_FILE to $PQRDIR"
    else
        log_message "Input file $IN_FILE not found in $MAIN_DIR. Skipping..."
        popd > /dev/null
        popd > /dev/null
        popd > /dev/null
        continue
    fi

    # Loop through each PQR file
    for pqr_file in $PQR_FILES; do
        # Check if the PQR file exists
        if [[ ! -f "$pqr_file" ]]; then
            log_message "PQR file $pqr_file does not exist. Skipping..."
            continue
        fi

        log_message "Processing PQR file: $pqr_file"

        # Define the path to the PQR file
        PQR_FILE="$pqr_file"

        # Define the path to the output file
        OUTPUT_FILE="${PQR_FILE%.pqr}.dx"

        # Create a temporary input file to avoid modifying the original apbs.in
        TEMP_IN_FILE="apbs_temp.in"
        cp "$IN_FILE" "$TEMP_IN_FILE"
        if [[ -f $OUTPUT_FILE ]]; then
            log_message "Output file $OUTPUT_FILE already exists. Skipping..."
            continue
        fi

        # Modify the temporary input file
        sed -i "2d" "$TEMP_IN_FILE"
        sed -i "2i\mol pqr $PQR_FILE" "$TEMP_IN_FILE"
        log_message "Modified $TEMP_IN_FILE with $PQR_FILE"

        # Run APBS
        log_message "Running APBS for $PQR_FILE..."
        apbs "$TEMP_IN_FILE" >> "$LOG" 2>&1 || \
        { log_message "APBS run failed for $PQR_FILE. Skipping..."; continue; }

        log_message "*****************************************************************"
        log_message "The potential file $OUTPUT_FILE has been generated."

        # Move the potential file to WORK_DIR
        if [[ -f "$POTENTIAL_FILE" ]]; then
            mv "$POTENTIAL_FILE" "$WORK_DIR/$OUTPUT_FILE" && \
            log_message "Moved $POTENTIAL_FILE to $WORK_DIR/$OUTPUT_FILE" || \
            log_message "Failed to move $POTENTIAL_FILE to $WORK_DIR/$OUTPUT_FILE"
        else
            log_message "Potential file $POTENTIAL_FILE not found after running APBS. Skipping move."
        fi

        log_message "*****************************************************************"
        echo >> "$LOG"
    done

    # Navigate back from PQRDIR
    popd > /dev/null

    # Navigate back from runDir
    popd > /dev/null

    # Navigate back from dirNams
    popd > /dev/null

    log_message "Completed processing for directory: $dirNams"
done

log_message "All specified directories have been processed."

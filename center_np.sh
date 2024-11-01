#!/bin/bash

# Description:
# This script automates the two-step GROMACS trjconv process to center the NP
# and wrap all atoms within the simulation box across multiple directories.
# Exit immediately if a command exits with a non-zero status
set -e

# Log
LOG="center_np.log"

# Load GROMACS
GROMACS

# Define input and output filenames for .gro files
GRO_IN="npt.gro"
GRO_TEMP="np_centered_temp.gro"
GRO_CENTERD="np_centered.gro"
GRO_CENTERD_WHOLE="np_centered_whole.gro"


# Define input and output filenames for .trr files
TRR_IN="npt.trr"
TRR_TEMP="np_centered_temp.trr"
TRR_CENTERD="np_centered.trr"
TRR_CENTERD_WHOLE="np_centered_whole.trr"

# Define the group numbers
GROUP_CENTER=11  # Replace with your actual group number for COR_APT
GROUP_WRAP=0     # System group number

# List of directory IDs to process
DIRECTORY_IDS=(10 20 30 40)
echo "Processing directories: ${DIRECTORY_IDS[@]}" > $LOG

# Loop through each directory ID
for dirId in "${DIRECTORY_IDS[@]}"; do
    # Construct the directory name
    dirNams="${dirId}Oda"
    
    # Check if the directory exists
    if [[ ! -d "$dirNams" ]]; then
        echo "Directory $dirNams does not exist. Skipping..."
        continue
    fi
    
    echo "Processing directory: $dirNams"
    
    # Navigate into the directory
    pushd "$dirNams" >> $LOG
    runDir=$(find . -maxdepth 1 -type d -name "*npt*For100ns" -print -quit)
    pushd $runDir
    
    # Check if necessary files exist
    if [[ ! -f "$GRO_IN" || ! -f "npt.tpr" || ! -f "index.ndx" ]]; then
        echo "Missing one of the required files (npt.gro, npt.tpr, index.ndx) in $dirNams. Skipping..."
        popd >> $LOG
        continue
    fi
    
    # ========================
    # Step 1: Center the NP
    # ========================
    echo "Step 1: Centering NP and keeping molecules whole..."
    echo "$GROUP_CENTER $GROUP_WRAP" | gmx_mpi trjconv -f "$GRO_IN" -s npt.tpr -n index.ndx -o "$GRO_TEMP" -center -pbc whole
    
    # ========================
    # Step 2: Wrap All Atoms
    # ========================
    echo "Step 2: Wrapping all atoms within the box..."
    echo "$GROUP_WRAP" | gmx_mpi trjconv -f "$GRO_TEMP" -s npt.tpr -n index.ndx -o "$GRO_CENTERD" -pbc atom

    # step 2.1: Make broken molecules whole
    echo "$GROUP_WRAP" | gmx_mpi trjconv -f "$GRO_CENTERD" -s npt.tpr -n index.ndx -o "$GRO_CENTERD_WHOLE" -pbc whole

    # Remove the temporary centered .gro file
    rm "$GRO_TEMP"
    rm "$GRO_CENTERD"
    
    # ========================
    # Step 3: Process Trajectory
    # ========================
    # Check if TRR_IN exists
    if [[ -f "$TRR_IN" ]]; then
        echo "Processing trajectory file: $TRR_IN"
        
        # Step 3.1: Center the NP in trajectory
        echo "$GROUP_CENTER $GROUP_WRAP" | gmx_mpi trjconv -f "$TRR_IN" -s npt.tpr -n index.ndx -o "$TRR_TEMP" -center -pbc whole
        
        # Step 3.2: Wrap all atoms in trajectory
        echo "$GROUP_WRAP" | gmx_mpi trjconv -f "$TRR_TEMP" -s npt.tpr -n index.ndx -o "$TRR_CENTERD" -pbc atom

        # step 3.3: Make broken molecules whole
        echo "$GROUP_WRAP" | gmx_mpi trjconv -f "$TRR_CENTERD" -s npt.tpr -n index.ndx -o "$TRR_CENTERD_Whole" -pbc whole

        # Remove the temporary centered .trr file
        rm "$TRR_TEMP"
        rm "$TRR_CENTERD"
        
        echo "Trajectory processing complete. Output saved as $TRR_CENTERD."
    else
        echo "Trajectory file $TRR_IN does not exist in $dirNams. Skipping trajectory processing..."
    fi
    
    # Confirmation message
    echo "Finished processing $dirNams. Final files:"
    echo " - Centered whole .gro: $GRO_CENTERD_WHOLE"
    if [[ -f "$TRR_CENTERD_WHOLE" ]]; then
        echo " - Centered whole .trr: $TRR_CENTERD_WHOLE"
    fi
    echo "----------------------------------------"
    
    # Navigate back to the main directory
    popd >> $LOG
    popd >> $LOG
done

echo "All specified directories have been processed."

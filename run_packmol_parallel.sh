#!/bin/bash

# Define the list of directories
dirs=( "50Oda" "100Oda" "150Oda" "200Oda" )

# Function to run packmol with water_box.inp in a specified directory
run_packmol() {
  dir="$1"
  cd "$dir" && /home/saeed/Downloads/packmol/packmol < water_box.inp
}

# Export the function to be used by parallel
export -f run_packmol

# Run the function in parallel for each directory
parallel run_packmol ::: "${dirs[@]}"

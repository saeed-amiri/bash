#!/bin/bash

# Define the list of directories
dirs=( "50Oda" "100Oda" "150Oda" )

for dir in "${dirs[@]}"; do
  (
    cd "$dir" || exit 1
    /home/saeed/Downloads/packmol/packmol < water_box.inp |tee log
  ) &
done

# Wait for all background jobs to finish
wait

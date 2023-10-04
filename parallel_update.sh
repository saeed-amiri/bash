#!/bin/bash

REPORT="./UPDATE_REPORT"
if [[ ! -f $REPORT ]]; then
    touch "$REPORT"
fi

# Function to log messages to the REPORT file
log_message() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$REPORT"
}

prepare_dirs() {
    local parentDir
    local updateDir
    local groDir
    local dirCount
    local count
    local filesToCopy

    parentDir="${1}Oda"
    cd "$parentDir" || { echo -e "$dir exists\n"; return; }

    updateDir="updateByAverage"
    dirCount=$(find . -maxdepth 1 -type d -regex './[0-9].*' | wc -l)
    count=1

    if [[ $dirCount -eq 0 ]]; then
        updateDir="${count}_${updateDir}"
    else
        for dir in */; do
            if [[ $dir =~ ^[0-9] ]]; then
                ((count++))
            fi
        done
        updateDir="${count}_${updateDir}"
    fi

    mkdir "$updateDir" || { echo "$updateDir directory exists!"; return; }

    groDir=$(find . -type d -name '*DropRestraintsafterNvt' -print -quit)
    echo -e "\n$groDir\n"

    # List of files to copy
    filesToCopy=(
        "index.ndx"
        "topol.top"
        "../APT_COR.itp"
        "$groDir/nvt.gro"
        "../update_param"
        "../slurm.update"
    )

    # Copy each file to the destination directory
    for file in "${filesToCopy[@]}"; do
        cp "$file" "$updateDir"
        if [ $? -eq 0 ]; then
            echo "Copied $file for $(pwd)"
        else
            echo "Error: Failed to copy $file to $updateDir"
            log_message "Failed in preparing update dir in: $(pwd)\n"
        fi
    done
}

update_files() {
    local parentDir
    local updateDir
    
    parentDir="$1"Oda
    local JobName="$1"Upd
    pushd "$parentDir" || exit 1
    updateDir=$(find . -type d -name '*updateByAverage' -print -quit)
    pushd "$updateDir" || exit 1
    slurmFile='slurm.update'
    sed -i "s/^#SBATCH --job-name.*/#SBATCH --job-name $JobName/" "$slurmFile"
    update="update_param"
    sed -i "s/^@LINE=.*/@LINE=DOUBLELOWERBOUND/" "$update"
    sed -i '26 a@NUMAPTES=-1' "$update"
    popd || exit
}

update_slurm() {
    local parentDir
    local updateDir
    local slurmFile
    local getData
    local updateGro
    
    parentDir="$1"Oda
    pushd "$parentDir" || exit 1
    updateDir=$(find . -type d -name '*updateByAverage' -print -quit)
    pushd "$updateDir" || exit 1
    slurmFile='slurm.update'
    getData='get_data.py'
    updateGro='update_pdb_itp'
    sed -i "/python/s|$updateGro|$getData|" "$slurmFile"
    popd || exit
}

split_trr() {
    local parentDir
    local updateDir
    local tprDir
    local tprFile
    local TIME_BETWEEN_FRAMES
    parentDir="$1"Oda
    pushd "$parentDir" || exit 1
    updateDir=$(find . -type d -name '*updateByAverage' -print -quit)
    pushd "$updateDir" || exit 1
    tprDir=$(find ../ -type d -name '*DropRestraintsafterNvt' -print -quit)
    tprFile="$tprDir"/nvt.tpr
    trrFile="$tprDir"/nvt.trr
    TOTAL_FRAMES=11
    TIME_BETWEEN_FRAMES=200

    for ((i=0; i<="$TOTAL_FRAMES"; i++)); do
        echo -e "System\n" | gmx_mpi trjconv -f "$trrFile" -s "$tprFile" -dump $(($i*TIME_BETWEEN_FRAMES)) -o frame_$i.gro
    done
    popd || exit
}

submit_jobs() {
    local parentDir
    local updateDir
    
    parentDir="$1"Oda
    pushd "$parentDir" || exit 1
    updateDir=$(find . -type d -name '*updateAfterDropConstraints' -print -quit)
    pushd "$updateDir" || exit 1
    slurmFile='slurm.update'
    sbatch "$slurmFile"
    popd || exit
}

get_data() {
    local parentDir
    local updateDir
    local TOTAL_FRAMES
    
    parentDir="$1"Oda
    pushd "$parentDir" || exit 1
    updateDir=$(find . -type d -name '*updateByAverage' -print -quit)
    pushd "$updateDir" || exit 1
    TOTAL_FRAMES=11
    for i in $(seq 0 "$TOTAL_FRAMES"); do
        python /scratch/projects/hbp00076/MyScripts/update_structure/codes/get_data.py frame_"$i".gro
    done
    popd || exit
}

get_pro_numbers() {
    local parentDir
    local updateDir

    parentDir="$1"Oda
    pushd "$parentDir" || exit 1
    updateDir=$(find . -type d -name '*updateByAverage' -print -quit)
    pushd "$updateDir" || exit 1
    local outputFile="combined.log"
    rm "$outputFile" || return
    touch "$outputFile"
    for logfile in get_data.log.*; do
        proNr=$(grep "The number of unprotonated aptes in water: \`APT\` is" "$logfile" | \
                awk -F "The number of unprotonated aptes in water: \`APT\` is " '{print $2}')
        angle=$(grep "The contact angle is:" "$logfile")
        echo "$logfile: APTES: $proNr, $angle " >> "$outputFile"
    done
    popd || exit
}

back_up() {
    local parentDir
    local backDir

    parentDir="$1"Oda
    pushd "$parentDir" || exit 1

    backDir="structureBeforeUpdate"
    mkdir "$backDir"
    
    # List of files to copy
    filesToMove=(
        "index.ndx"
        "topol.top"
        "silica_water.pdb"
        "system.gro"
    )

    # Move each file to the destination directory
    for file in "${filesToMove[@]}"; do
        mv "$file" "$backDir"
        if [ $? -eq 0 ]; then
            echo "Move $file for $(pwd)"
        else
            echo "Error: Failed to move $file to $backDir"
            log_message "Failed in preparing update dir in: $(pwd)\n"
        fi
    done
    popd || exit
}

copy_updated() {
    local parentDir

    parentDir="$1"Oda
    pushd "$parentDir" || exit 1
    updateDir=$(find . -type d -name '*updateByAverage' -print -quit)
    cp "$updateDir"/topol_updated.top topol.top
    cp "$updateDir"/APT_COR_updated.itp APT_COR.itp
    cp "$updateDir"/updated_system.gro system.gro
    popd || exit
}

update_topol() {
    local parentDir

    parentDir="$1"Oda
    pushd "$parentDir" || exit 1
    
    sed -i '1 a; topology after updating protonation' topol.top

    # Replace the line
    sed -i 's|#include "../APT_COR.itp"|#include "./APT_COR.itp"|' topol.top

    # Remove the block of lines
    sed -i '/; Restraints on NP/,/#endif/d' topol.top
    popd || exit
}

export -f log_message prepare_dirs update_files submit_jobs back_up copy_updated
export -f update_topol update_slurm split_trr get_data get_pro_numbers
export REPORT

# Define the list of directories
# dirs=( "5" )
dirs=( "5" "10" "15" "20" "50" "100" "150" "200" )

case $1 in
    'prepare')
        parallel prepare_dirs ::: "${dirs[@]}"
    ;;
    'update')
        parallel update_files ::: "${dirs[@]}"
    ;;
    'upslurm')
        parallel update_slurm ::: "${dirs[@]}"
    ;;
    'split')
        parallel split_trr ::: "${dirs[@]}"
    ;;
    'getData')
        parallel get_data ::: "${dirs[@]}"
    ;;
    'getPro')
        parallel get_pro_numbers ::: "${dirs[@]}"
    ;;
    'submit')
        parallel submit_jobs ::: "${dirs[@]}"
    ;;
    'backup')
        parallel back_up ::: "${dirs[@]}"
    ;;
    'copy_updated')
        parallel copy_updated ::: "${dirs[@]}"
    ;;
    'update_topol')
        parallel update_topol ::: "${dirs[@]}"
    ;;
    'delete')
        # find . -type d -name "updateSuffix" -exec rm -r {} +
        echo -e "\n\t\tDo it manually@@@!!!!!!\n"
    ;;
    *)
        echo "Invalid argument. Please use 'prepare', 'update', 'upslurm', 'split', \
              'getData', 'getPro', 'submit', 'backup', 'copy_updated', 'update_topol', \
              'delete'"
    ;;
esac

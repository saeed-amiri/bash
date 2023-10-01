#!/bin/bash

REPORT="./UPDATE_REPORT"
if [[ ! -f $REPORT ]]; then
    touch $REPORT
fi

# Function to log messages to the REPORT file
log_message() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$REPORT"
}

prepare_dirs(){
    local parentDir
    local updateDir
    local groDir
    local dirCount
    local count
    local filesToCopy
    
    parentDir="$1"Oda
    cd $parentDir || echo -e "$dir exsits\n"
    updateDir="updateAfterDropConstraints"
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
    
    mkdir "$updateDir" || echo " $updateDir directory exsit!"
    
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


function update_files(){
    local parentDir
    local updateDir
    
    parentDir="$1"Oda
    local JobName="$1"Upd
    pushd "$parentDir" || exit 1
    updateDir=$(find . -type d -name '*updateAfterDropConstraints' -print -quit)
    pushd "$updateDir" || exit 1
    slurmFile='slurm.update'
    sed -i "s/^#SBATCH --job-name.*/#SBATCH --job-name $JobName/" "$slurmFile"
}

function submit_jobs() {
    local parentDir
    local updateDir
    
    parentDir="$1"Oda
    pushd "$parentDir" || exit 1
    updateDir=$(find . -type d -name '*updateAfterDropConstraints' -print -quit)
    pushd "$updateDir" || exit 1
    slurmFile='slurm.update'
    sbatch "$slurmFile"
}

function back_up() {
    local parentDir
    local backDir

    parentDir="$1"Oda
    pushd "$parentDir" || exit 1

    backDir="structureBeforeUpdate"
    mkdir $backDir
    
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
}


export -f log_message prepare_dirs update_files submit_jobs back_up
export REPORT

# Define the list of directories
dirs=( "10" "15" "20" "200" )
# dirs=( "10" "15" "20" "50" "100" "150" "200" )
updateSuffix="updateAfterDropConstraints"

case $1 in
    'prepare')
        parallel prepare_dirs ::: "${dirs[@]}"
    ;;
    'update')
        parallel update_files ::: "${dirs[@]}"
    ;;
    'submit')
        parallel submit_jobs ::: "${dirs[@]}"
    ;;
    'backup')
        parallel back_up ::: "${dirs[@]}"
    ;;
    'delete')
        # find . -type d -name "updateSuffix" -exec rm -r {} +
        echo -e "\n\t\tDo it manually@@@!!!!!!\n"
    ;;
    *)
        echo "Invalid argument. Please use 'prepare', 'delete', 'em', 'nvt', or 'npt'."
    ;;
esac



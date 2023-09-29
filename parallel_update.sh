#!/bin/bash

REPORT="./DROP_REPORT"
if [[ ! -f $REPORT ]]; then
    touch $REPORT
fi

# Function to log messages to the REPORT file
log_message() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$REPORT"
}

prepare_dirs(){
    local updateDir
    local groDir
    local dirCount
    local count
    local filesToCopy

    parentDir="$1"Oda
    pushd "$parentDir" || exit 1
    
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
    
    groDir=$(find . -type d -name '*afterNptDropConstraints' -print -quit)
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

export -f log_message prepare_dirs
export REPORT

# Define the list of directories
dirs=( "5" "10" "15" "20" "200" "proUnpro")


case $1 in
    'prepare')
        parallel prepare_dirs ::: "${dirs[@]}"
    ;;
    'delete')
        find . -type d -name '*updateAfterDropConstraints*' -exec rm -r {} +
    ;;
    *)
        echo "Invalid argument. Please use 'structure', 'index', 'em', 'nvt', or 'npt'."
    ;;
esac



#!/bin/bash

# Copy final data from previous simulation batch

ParentDir="/scratch/projects/hbp00076/PRE_DFG_18Oct23/runs"
ChildDirs=( "single_np" "no_nanoparticle" )

copy_files(){
    
    local FilesToCopy
    local sourceDir
    local targetDir

    FilesToCopy=(
        "npt.gro"
        "index.ndx"
        "topol.top"
        "APT_COR.itp"
        "D10_charmm.itp"
        "ODAp_charmm.itp"
    )

    targetDir=$(basename "$1")
    sourceDir=$(find "$1" -type d -name "*_npt_*Long300ns")
    echo "$sourceDir"
    if [[ -z "$sourceDir" ]]; then
        exit 1
    fi
    mkdir "$targetDir"  || { echo "$targetDir exists, continue"; return; }
    for file in "${FilesToCopy[@]}"; do
        cp "$sourceDir/$file" "$targetDir/"
    done
}

export -f copy_files
case $1 in
    'copy')
        for cdir in "${ChildDirs[@]}"; do
            OdaDirs=$(ls -d "$ParentDir"/"$cdir"/*Oda )
            mkdir "$cdir" || { echo "$cdir exists, continue"; return; }
            pushd "$cdir" || return
                parallel copy_files ::: "${OdaDirs[@]}"
            popd || return
        done
    ;;
    *)
        echo -e "Invalid argument. Please use 'copy', \n"
esac

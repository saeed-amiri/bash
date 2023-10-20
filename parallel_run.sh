#!/bin/bash

# Initialize report file
REPORT="./PARA_SUBMIT_REPORT"
if [[ ! -f $REPORT ]]; then
    touch $REPORT
fi

# Function to log messages to the REPORT file
log_message() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$REPORT"
}

log_message "Looking at the following dirs:\n\t${dirs[*]}\n"

mk_parent_dirs() {
    local dir="$1"Oda
    local localDir
    mkdir $dir || echo -e "$dir exsits\n"
}

prepare_topol() {
    # Function to run packmol with water_box.inp in a specified directory
    local ODA="$1"
    local dir="$ODA"Oda
    local CLA=168
    local NaCl=15
    local IONS=$(( $CLA + $ODA ))
    local topol="topol.top"
    local source_file="./topol.top"

    [ -d "./$dir" ] || { echo "Directory ./$dir does not exist, skipping..."; return 1; }
    cp $source_file "$dir"/"$topol"
    echo "doing ./$dir/$topol"
    
    if ! [[ "$ODA" =~ ^[0-9]+$ ]]; then
        ODA=10
        IONS=$(( $CLA + $ODA ))
    fi
    # Replace the existing CLA value
    sed -i "s/^\(CLA[[:space:]]*\).*/\1$(printf '%3s' $IONS)/" ./$dir/$topol
    sed -i "s/^\(ODN[[:space:]]*\).*/\1$(printf '%2s' $ODA)/" ./$dir/$topol
    
    # Add another line after the line that starts with ODN
    sed -i "/^ODN/a\CLA$(printf '%22s' $NaCl)" ./$dir/$topol
}

mk_structure() {
    local dir="$1"Oda
    cd "$dir" || exit 1
    log_message "Converting structure for $dir ..."
    gmx_mpi editconf -f silica_water.pdb -o system.gro -c -d 0
}

mk_index() {
    local dir="$1"Oda
    cd "$dir" || exit 1
    rm index.ndx || return
    log_message "Creating index for $dir ..."
    { echo "9|10"; echo q; } | gmx_mpi make_ndx -f system.gro -o index.ndx
}

do_em() {
    local dir="$1"Oda
    local JobName="$1"WPO
    local slurm_file="slurm.em"
    local nodesNr=9
    local tasksNr
    tasksNr=$(( $nodesNr * 96 ))
    cd "$dir" || exit 1
    log_message "Submitting job for $dir ..."
    cp ../em.mdp .
    cp ../$slurm_file .
    sed -i "s/^#SBATCH --job-name.*/#SBATCH --job-name $JobName/" "$slurm_file"
    sed -i "s/^#SBATCH --nodes.*/#SBATCH --nodes=$nodesNr/" "$slurm_file"
    sed -i "s/^#SBATCH --ntasks.*/#SBATCH --ntasks=$tasksNr/" "$slurm_file"
    sed -i "s#LABEL=.*#LABEL=afterAverageUpdate#" "$slurm_file"
    Jobid=$(sbatch --parsable $slurm_file)
    log_message "Submitted job for: $dir -> $Jobid \n"
}

do_nvt(){
    local dir="$1"Oda
    local JobName="$1"WPO
    local slurm_file="slurm.nvt"
    cd "$dir" || exit 1
    log_message "Submitting job for $dir ..."
    cp ../nvt.mdp .
    cp ../$slurm_file .
    sed -i "s/^#SBATCH --job-name.*/#SBATCH --job-name $JobName/" "$slurm_file"
    sed -i "s#STRUCTURE=.*#STRUCTURE=./1_em/em.gro#" "$slurm_file"
    
    Jobid=$(sbatch --parsable $slurm_file)
    log_message "Submitted job for: $dir -> $Jobid \n"
    echo -e "Submitted job for: $dir -> $Jobid \n"
}

do_npt(){
    local dir="$1"Oda
    local JobName="$1"WPO
    local slurm_file="slurm.npt"
    local strucDir
    local nodesNr=10
    local tasksNr
    tasksNr=$(( $nodesNr * 96 ))
    pushd "$dir" || exit 1
    log_message "Submitting job for $dir ..."
    strucDir=$(find . -type d -name '*em_afterAverageUpdate' -print -quit)
    cp ../npt.mdp .
    cp ../$slurm_file .
    if [[ -d "$strucDir" ]]; then
        sed -i "s/^#SBATCH --nodes.*/#SBATCH --nodes=$nodesNr/" "$slurm_file"
        sed -i "s/^#SBATCH --ntasks.*/#SBATCH --ntasks=$tasksNr/" "$slurm_file"
        sed -i "s/^#SBATCH --job-name.*/#SBATCH --job-name $JobName/" "$slurm_file"
        sed -i "s#STRUCTURE=.*#STRUCTURE=./$strucDir/em.gro#" "$slurm_file"
        sed -i "s#LABEL=.*#LABEL=afterEmAverageUpdate#" "$slurm_file"

        Jobid=$(sbatch --parsable $slurm_file)
        log_message "Submitted job for: $dir -> $Jobid \n"
        echo -e "Submitted job for: $dir -> $Jobid \n"
    else
        echo "$strucDir does not exsit in $(pwd)"
    fi
    popd
}

drop_restraints() {
    local dir="$1"Oda
    local JobName="$1"WPO
    local slurm_file="slurm.nvt"
    local strucDir="3_npt_afterNvt/npt.gro"
    local nodesNr=9
    local tasksNr
    tasksNr=$(( $nodesNr * 96 ))
    pushd "$dir" || exit 1
    log_message "Submitting job for $dir ..."
    cp ../nvt.mdp .
    cp ../$slurm_file .
    if [[ -f "$strucDir" ]]; then
        sed -i "s/^#SBATCH --nodes.*/#SBATCH --nodes=$nodesNr/" "$slurm_file"
        sed -i "s/^#SBATCH --ntasks.*/#SBATCH --ntasks=$tasksNr/" "$slurm_file"
        sed -i "s/^#SBATCH --job-name.*/#SBATCH --job-name $JobName/" "$slurm_file"
        sed -i "s#STRUCTURE=.*#STRUCTURE=./$strucDir#" "$slurm_file"
        sed -i "s#LABEL=.*#LABEL=DropRestraintsafterNvt#" "$slurm_file"

        Jobid=$(sbatch --parsable $slurm_file)
        log_message "Submitted job for: $dir -> $Jobid \n"
        echo -e "Submitted job for: $dir -> $Jobid \n"
    else
        echo "$strucDir does not exsit in $(pwd)"
    fi

}

prepare_long_run() {
    local dir="$1"Oda
    local JobName="$1"WPO
    local slurmFile="slurm.long_run"
    local slurmContinue="slurm.continue"
    local submitFile="submit.sh"
    local dirCount
    local strucDir
    local runDir
    local nodesNr=12
    local tasksNr
    local groFile
    tasksNr=$(( $nodesNr * 96 ))
    pushd "$dir" || exit 1
    log_message "Submitting job for $dir ..."
    runDir="npt_afterEmUpAveLong300ns"

    dirCount=$(find . -maxdepth 1 -type d -regex './[0-9].*' | wc -l)
    count=1
    if [[ $dirCount -eq 0 ]]; then
        runDir="${count}_${runDir}"
    else
        for dir in */; do
            if [[ $dir =~ ^[0-9] ]]; then
                ((count++))
            fi
        done
        runDir="${count}_${runDir}"
    fi
    mkdir "$runDir" || { echo "$runDir directory exists!"; return; }
    
    pushd "$runDir" || exit 1
    strucDir=$(find ../ -type d -name '*em_afterAverageUpdate' -print -quit)
    groFile="$strucDir"/em.gro

    # List of files to copy
    filesToCopy=(
        "../../run.sh"
        "../../npt.mdp"
        "../../$slurmFile"
        "../../$slurmContinue"
        "../../$submitFile"
        "../../D10_charmm.itp"
        "../../ODAp_charmm.itp"
        "../APT_COR.itp"
        "../topol.top"
        "../index.ndx"
    )

    # copy each file to the destination directory
    for file in "${filesToCopy[@]}"; do
        cp "$file" .
        if [ $? -eq 0 ]; then
            echo "cp $file for $(pwd)"
        else
            echo "Error: Failed to move $file to here"
            log_message "Failed in preparing update dir in: $(pwd)\n"
        fi
    done

    for slurm_file in $slurmFile $slurmContinue; do
        sed -i "s/^#SBATCH --nodes.*/#SBATCH --nodes $nodesNr/" "$slurm_file"
        sed -i "s/^#SBATCH --ntasks.*/#SBATCH --ntasks $tasksNr/" "$slurm_file"
    done

    sed -i "s#JobName=.*#JobName=$JobName#" "$submitFile"
    sed -i "s#STRUCTURE=.*#STRUCTURE=$groFile#" "$slurmFile"
    sed -i 's|#include "../APT_COR.itp"|#include "./APT_COR.itp"|' topol.top
    sed -i 's|#include "../D10_charmm.itp"|#include "./D10_charmm.itp"|' topol.top
    sed -i 's|#include "../ODAp_charmm.itp"|#include "./ODAp_charmm.itp"|' topol.top
    sed -i 's|../../../|../../../../|g' topol.top
    popd || exit 1
}

run_long() {
    local dir="$1"Oda
    local runDir
    pushd $dir || exit 1
    runDir=$(find . -type d -name '*npt_afterLong300nsFor100ns' -print -quit)
    pushd $runDir || exit 1
    bash run.sh
    popd || exit 1
}


prepare_production_run() {
    local dir="$1"Oda
    local JobName="$1"Oda
    local slurmFile="slurm.long_run"
    local slurmContinue="slurm.continue"
    local submitFile="submit.sh"
    local exsitDirs
    local existing_integer
    local largest_integer
    local strucDir
    local runDir
    local nodesNr=12
    local tasksNr
    local groFile

    tasksNr=$(( $nodesNr * 96 ))
    pushd "$dir" || exit 1
    log_message "Submitting job for $dir ..."
    runDir="npt_afterLong300nsFor100ns"
    exsitDirs=$( ls -d */ )

    largest_integer=0
    # Loop through the directory names
    for dir_name in "${exsitDirs[@]}"; do
        if [[ $dir_name =~ ^([0-9]+)_ ]]; then
            existing_integer="${BASH_REMATCH[1]}"
            if ((existing_integer > largest_integer)); then
                largest_integer=$existing_integer
            fi
        fi
    done
    
    ((largest_integer++))
    runDir="${largest_integer}_${runDir}"

    mkdir "$runDir" || { echo "$runDir directory exists!"; return; }
    
    pushd "$runDir" || exit 1
    strucDir=$(find ../ -type d -name '*_npt_*Long300ns' -print -quit)
    groFile="$strucDir"/npt.gro
    # List of files to copy
    filesToCopy=(
        "../../run.sh"
        "../../npt_prod.mdp"
        "../../$slurmFile"
        "../../$slurmContinue"
        "../../$submitFile"
        "../../D10_charmm.itp"
        "../../ODAp_charmm.itp"
        "$strucDir/topol.top"
        "$strucDir/index.ndx"
    )
    # copy each file to the destination directory
    for file in "${filesToCopy[@]}"; do
        cp "$file" .
        if [ $? -eq 0 ]; then
            echo "cp $file for $(pwd)"
        else
            echo "Error: Failed to move $file to here"
            log_message "Failed in preparing update dir in: $(pwd)\n"
        fi
    done

    for slurm_file in $slurmFile $slurmContinue; do
        sed -i "s/^#SBATCH --nodes.*/#SBATCH --nodes $nodesNr/" "$slurm_file"
        sed -i "s/^#SBATCH --ntasks.*/#SBATCH --ntasks $tasksNr/" "$slurm_file"
    done

    sed -i "s#JobName=.*#JobName=$JobName#" "$submitFile"
    sed -i "s#STRUCTURE=.*#STRUCTURE=$groFile#" "$slurmFile"
    
}

export -f mk_structure mk_index do_em do_nvt do_npt log_message mk_parent_dirs prepare_topol drop_restraints
export -f prepare_long_run run_long prepare_production_run

# Define the list of directories
# dirs=( "10" "15" "20" "200" "proUnpro" )
# dirs=( "5" )
dirs=( "10" "15" "20" "50" "100" "150" "200" "300" "zero" )

case $1 in
'mk_parents')
    parallel mk_parent_dirs ::: "${dirs[@]}"
;;
'topol')
    parallel prepare_topol ::: "${dirs[@]}"
;;
'structure')
    parallel mk_structure ::: "${dirs[@]}"
    ;;
'index')
    parallel mk_index ::: "${dirs[@]}"
    ;;
'em')
    parallel do_em ::: "${dirs[@]}"
    ;;
'nvt')
    parallel do_nvt ::: "${dirs[@]}"
    ;;
'npt')
    parallel do_npt ::: "${dirs[@]}"
    ;;
'drop')
    parallel drop_restraints ::: "${dirs[@]}"
    ;;
'prepareLong')
    parallel prepare_long_run ::: "${dirs[@]}"
    ;;
'runLong')
    parallel run_long ::: "${dirs[@]}"
    ;;
'prepareProd')
    parallel prepare_production_run ::: "${dirs[@]}"
    ;;
*)
    echo "Invalid argument. Please use 'structure', 'mk_parents',topol, 'index', 'em', 'nvt', 'npt', or 'drop'."
    ;;
esac

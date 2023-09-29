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
    log_message "Creating index for $dir ..."
    { echo "9|10"; echo q; } | gmx_mpi make_ndx -f system.gro -o index.ndx
}

do_em() {
    local dir="$1"Oda
    local JobName="$1"WPO
    local slurm_file="slurm.em"
    cd "$dir" || exit 1
    log_message "Submitting job for $dir ..."
    cp ../em.mdp .
    cp ../$slurm_file .
    sed -i "s/^#SBATCH --job-name.*/#SBATCH --job-name $JobName/" "$slurm_file"
    Jobid=$(sbatch --parsable $slurm_file)
    log_message "Submitted job for: $dir -> $Jobid \n"
}

do_nvt(){
    local dir="$1"Oda
    local JobName="$1"NoO
    local slurm_file="slurm.nvt"
    cd "$dir" || exit 1
    log_message "Submitting job for $dir ..."
    cp ../nvt.mdp .
    cp ../$slurm_file .
    sed -i "s/^#SBATCH --job-name.*/#SBATCH --job-name $JobName/" "$slurm_file"
    sed -i "s#STRUCTURE=.*#STRUCTURE=./1_em/em.gro#" "$slurm_file"
    sed -i "s#LABEL=.*#LABEL=after_em1#" "$slurm_file"
    
    Jobid=$(sbatch --parsable $slurm_file)
    log_message "Submitted job for: $dir -> $Jobid \n"
    echo -e "Submitted job for: $dir -> $Jobid \n"
}

do_npt(){
    local dir="$1"Oda
    local JobName="$1"NoO
    local slurm_file="slurm.npt"
    cd "$dir" || exit 1
    log_message "Submitting job for $dir ..."
    cp ../npt.mdp .
    cp ../$slurm_file .
    sed -i "s/^#SBATCH --job-name.*/#SBATCH --job-name $JobName/" "$slurm_file"
    sed -i "s#STRUCTURE=.*#STRUCTURE=./2_nvt_afterEm1/nvt.gro#" "$slurm_file"
    sed -i "s#LABEL=.*#LABEL=afterNvt#" "$slurm_file"
    
    Jobid=$(sbatch --parsable $slurm_file)
    log_message "Submitted job for: $dir -> $Jobid \n"
    echo -e "Submitted job for: $dir -> $Jobid \n"
}


export -f mk_structure mk_index do_em do_nvt do_npt log_message mk_parent_dirs prepare_topol

# Define the list of directories
# dirs=( "test" )
dirs=( "5" "10" "15" "20" "200" "proUnpro" )

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
*)
    echo "Invalid argument. Please use 'structure', 'index', 'em', 'nvt', or 'npt'."
    ;;
esac

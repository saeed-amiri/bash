#!/bin/bash

# Initialize report file
REPORT="./PARA_SUBMIT_REPORT"

# Define the list of directories
dirs=( "5" "10" "15" "20" "50" "100" "150" "200" "proUnpro" )

# Function to log messages to the REPORT file
log_message() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$REPORT"
}

log_message "Looking at the following dirs:\n\t${dirs[*]}\n"

mk_structure () {
    local dir="$1"Oda
    cd "$dir" || exit 1
    echo "Converting structure for $dir ..."
    gmx_mpi editconf -f water_box.pdb -o system.gro -c -d 0
}

mk_index() {
    local dir="$1"Oda
    cd "$dir" || exit 1
    echo "Creating index for $dir ..."
    echo "q" | gmx_mpi make_ndx -f system.gro -o index.ndx
}

do_em() {
    local dir="$1"Oda
    local JobName="$1"NoO
    local slurm_file="slurm.em"
    cd "$dir" || exit 1
    echo "Submitting job for $dir ..."
    cp ../$slurm_file .
    sed -i "s/^#SBATCH --job-name.*/#SBATCH --job-name $JobName/" "$slurm_file"
    Jobid=$(sbatch --parsable $slurm_file)
    log_message "Submitted job for: $dir -> $Jobid \n"
}

export -f mk_structure mk_index do_em log_message

case $1 in
'structure')
    parallel mk_structure ::: "${dirs[@]}"
    ;;
'index')
    parallel mk_index ::: "${dirs[@]}"
    ;;
'em')
    parallel do_em ::: "${dirs[@]}"
    ;;
*)
    echo "Invalid argument. Please use 'structure', 'index', or 'em'."
    ;;
esac

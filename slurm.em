#!/bin/bash 
#SBATCH --job-name NeW@EM
#SBATCH --cpus-per-task=1
#SBATCH --nodes=1
#SBATCH --ntasks=48
#SBATCH --time 12:00:00
#SBATCH -A hbp00076

THREADS=2
export SLURM_CPU_BIND=none
export OMP_NUM_THREADS=$THREADS
export GMX_MAXCONSTRWARN=-1

module load intel
module load impi
module load gromacs/2021.2-plumed

# input gro file for starting point
STRCTURE=./silica_water.gro
# Style of run
STYLE=em
# mdp file
MDP_FILE="$STYLE.mdp"
# Name of the simulation
LABEL=neutShellOil90DepAptesOdap50
# Output to check grompp
TPRFILE=$STYLE.tpr
# Directory to move all the data to it after job done
DIR="$STYLE"_"$LABEL"
# Mail info, if True will send email
if [ -f $TPRFILE ]; then
    rm $TPRFILE
fi
# check if the structure file exists
if [ ! -f "$STRCTURE" ]; then
    echo "Error: the structure file does not exist!"
    exit 1
fi

# Naming the dirs, initiate with an integer
dir_count=$(find . -maxdepth 1 -type d -regex './[0-9].*' | wc -l)
count=1
if [[ $dir_count -eq 0 ]]; then
    DIR="${count}_${DIR}"
else
    for dir in */; do
        if [[ $dir =~ ^[0-9] ]]; then
            ((count++))
        fi
    done
    DIR="${count}_${DIR}"
fi

cat << EOF

 *******************
 Directory is $DIR
 *******************
 The topology file contains:

EOF

cat "$MDP_FILE"

gmx_mpi grompp -f $MDP_FILE \
               -c $STRCTURE \
               -r $STRCTURE \
               -p topol.top \
               -n index.ndx \
               -o $STYLE.tpr \
               -maxwarn -1

if [ -f $TPRFILE ]; then
srun --cpu-per-task=$SLURM_CPUS_PER_TASK \
     gmx_mpi mdrun -v -s $TPRFILE \
                      -o $STYLE \
                      -e $STYLE \
                      -x $STYLE \
                      -c $STYLE \
                      -cpo $STYLE \
                      -ntomp $THREADS \
                      -pin on
else
    PWD=$(pwd)
    echo "The job in dir: ${PWD} crashed, jobid: ${SLURM_JOB_ID}"
fi

if [ -f $STYLE.gro ]; then
    mkdir $DIR
    mv $STYLE.* $DIR/
    mv md.log $DIR/
    mv mdout.mdp $DIR/
    cp $DIR/$STYLE.mdp .
    echo "My Slurm job ID is: ${SLURM_JOB_ID}" > $DIR/JOBID
fi

cat << EOF

 *******************
 Directory is $DIR
 *******************

EOF

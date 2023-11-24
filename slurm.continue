#!/bin/bash 
#SBATCH --job-name DoubNP
#SBATCH --nodes=12
#SBATCH --ntasks=1152
#SBATCH --time 12:00:00
#SBATCH --constraint=turbo_on
#SBATCH -A hbp00076

echo $(date)
echo -e "================================================================================\n"

THREADS=2
export SLURM_CPU_BIND=none
export SLURM_CPUS_PER_TASK=$THREADS
export OMP_NUM_THREADS=$THREADS
export GMX_MAXCONSTRWARN=-1

module load intel/19.1.3
module load impi/2019.9
module load gromacs/2021.2-plumed

STYLE=npt

if [ -f $TPRFILE ]; then
     srun --cpus-per-task=$SLURM_CPUS_PER_TASK \
          gmx_mpi mdrun -v -s $STYLE \
                        -o $STYLE \
                        -e $STYLE \
                        -x $STYLE \
                        -c $STYLE \
                        -cpo $STYLE \
                        -cpi $STYLE.cpt \
                        -ntomp $THREADS \
                        -dlb yes \
                        -pin on
fi
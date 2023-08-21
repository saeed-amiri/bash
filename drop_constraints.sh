#!/bin/bash

# Usage: Drop the constrains from NPs gradually

# Set variables
REPORT="./RESUBMIT_REPORT"
JobName="DropCo"
CHECKFILE=nvt.gro
SLURM_FILE=slurm.drop_nvt

# Make sure of the job name in slurm
sed -i "s/^#SBATCH --job-name.*/#SBATCH --job-name $JobName/" $SLURM_FILE

# Function to log messages to the REPORT file
log_message() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$REPORT"
}

check_Jobid(){
        if [ -z "$1" ]; then
            LASTLINE=$(sacct | grep $JobName | tail -1 | awk '{print $1}')
            Jobid="${LASTLINE%%.*}"
        fi
}

# Function to check the job status
check_status() {
    local jobid=$1
    local status_variable=$(sacct | grep "$jobid" | grep standard | awk '{print $6}')
    
    log_message "Status of job $jobid is $status_variable"

    if [ "$status_variable" == "COMPLETED" ]; then
        log_message "Job completed! Renaming nvt.gro"
    elif [ "$status_variable" == "TIMEOUT" ]; then
        log_message "Job: $jobid did not finish on time! EXIT!"
        exit 1
    elif [ "$status_variable" == "RUNNING" ]; then
        while [ "$status_variable" == "RUNNING" ]; do
            log_message "$jobid is still running! Waiting for another hour..."
            sleep 1h
            status_variable=$(sacct | grep "$jobid" | grep standard | awk '{print $6}')
        done
        check_status "$jobid"   # Recursive call to check_status
    elif [ "$status_variable" == "FAILED" ]; then
        # Handle job failure
        log_message "Job failed; kill nohup PID and exit 1"
        nohupFile=nohup.PID
        nohupPID=$(tac "$nohupFile" | grep -m 1 -v '^$')
        kill "$nohupPID"
        exit 1
    fi
}

# Initialize constraint
INITIAL_FORCE=5000
# Dropping value
DROP_STEP=500

# Gradually decrease constraints
while [ "$INITIAL_FORCE" -ge "$DROP_STEP" ]; do
    UPDATED_FORCE=$((INITIAL_FORCE - DROP_STEP))
    
    # Update constraints in POSRES files
    for POSRES_FILE in STRONG_POSRES1.itp STRONG_POSRES2.itp; do
        sed -i "s/$INITIAL_FORCE/$UPDATED_FORCE/g" "$POSRES_FILE"
    done
    INITIAL_FORCE="$UPDATED_FORCE"

    # Submit job and monitor
    Jobid=$(sbatch --parsable $SLURM_FILE)
    log_message "Submitting job: $Jobid , Constraint Force: $UPDATED_FORCE"
    log_message "Sleep for 2 hours before checking status."

    sleep 2h
    
    # Check the state after waking up
    check_Jobid "$Jobid"
    # Check the status of the job
    check_status "$Jobid"
    
    # Rename nvt.gro and update SLURM script
    UPDATE_GRO=nvt_"$UPDATED_FORCE".gro

    if [ ! -f "$CHECKFILE" ]; then
       mv "$CHECKFILE" "$UPDATE_GRO"
       mv md.log md_"$UPDATED_FORCE".log
    fi 

    # Update structure path in SLURM script
    sed -i "s/^STRCTURE=.*/STRCTURE=.\/$UPDATE_GRO/" "$SLURM_FILE"
    log_message "Starting new job with initital structure: $UPDATE_GRO"
done

if [ -f nvt_$DROP_STEP.gro ]; then
    sed -i 's/^gmx_mpi grompp -f.*/gmx_mpi grompp -f nvt_noConstraints.mdp \\/' $SLURM_FILE
    Jobid=$(sbatch --parsable $SLURM_FILE)
    log_message "Submitting final job with id: $Jobid, and sleep 2 hours"
    sleep 12h
    # Check the state after waking up
    check_Jobid "$Jobid"
    # Check the status of the job
    check_status "$Jobid"
fi

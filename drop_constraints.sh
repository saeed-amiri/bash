#!/bin/bash

# Usage: Drop the constrains from NPs gradually

# Set variables
REPORT="./RESUBMIT_REPORT"
JobName="100Drop"
CHECKFILE="npt.gro"
SLURM_FILE="slurm.drop_npt"
MDP_FILE="npt.mdp"
TOP_FILE="topol.top"
INSTRUCTURE="./nvt.gro"
INDEX="index.ndx"

SLEEPTIME=40m
SNOOZE=10m


# Function to check if a file exists and print a message
check_file_exists() {
    local file_path="$1"
    if [ -f "$file_path" ]; then
        echo "File $file_path exists."
    else
        echo "File $file_path does not exist. EXIT!"
        exit 1
    fi
}

# Function to check #include statements in a file
check_includes() {
    local input_file="$1"
    # Regular expression pattern to match #include statements and capture the file path
    local pattern='#include[[:space:]]*"([^"]*)"'
    while IFS= read -r line; do
        # Check if the line matches the pattern
        if [[ $line =~ $pattern ]]; then
            # The captured file path is in "${BASH_REMATCH[1]}"
            file_path="${BASH_REMATCH[1]}"
            check_file_exists "$file_path"
        fi
    done < "$input_file"
}

# Call the function to check input files
check_file_exists "$TOP_FILE"
check_file_exists "$INSTRUCTURE"
check_file_exists "$INDEX"
check_includes "$TOP_FILE"

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
        log_message "Job completed!\n"
    elif [ "$status_variable" == "TIMEOUT" ]; then
        log_message "Job: $jobid did not finish on time! EXIT!"
        exit 1
    elif [ "$status_variable" == "RUNNING" ]; then
        while [ "$status_variable" == "RUNNING" ]; do
            log_message "$jobid is still running! Snooze for $SNOOZE ..."
            sleep $SNOOZE
            status_variable=$(sacct | grep "$jobid" | grep standard | awk '{print $6}')
        done
        check_status "$jobid"   # Recursive call to check_status
    elif [ "$status_variable" == "FAILED" ]; then
        # Handle job failure
        log_message "Job failed; kill nohup PID and exit 1\n"
        nohupFile=nohup.PID
        nohupPID=$(tac "$nohupFile" | grep -m 1 -v '^$')
        kill "$nohupPID"
        exit 1
    elif [ "$status_variable" == "PENDING" ]; then
        log_message "Job still PENDING, sleep for $SLEEPTIME !!!"
        sleep $SLEEPTIME
        check_status "$Jobid"   # Recursive call to check_status
    fi
}

# Initialize constraint
INITIAL_FORCE=5000
# Dropping value
DROP_STEP=1000

sed -i "s|^STRUCTURE=.*|STRUCTURE=${INSTRUCTURE}|" "$SLURM_FILE"
# Gradually decrease constraints
while [ "$INITIAL_FORCE" -gt "$DROP_STEP" ]; do
    UPDATED_FORCE=$((INITIAL_FORCE - DROP_STEP))
    
    # Update constraints in POSRES files
    POSRES_FILE="STRONG_POSRES.itp"
    sed -i "s/$INITIAL_FORCE/$UPDATED_FORCE/g" "$POSRES_FILE"
    # Update the intital force
    INITIAL_FORCE="$UPDATED_FORCE"

    # Submit job and monitor
    # make sure the of the name of the mdp file
    sed -i "s/^MDP_FILE=.*/MDP_FILE=npt.mdp/" "$SLURM_FILE"
    Jobid=$(sbatch --parsable $SLURM_FILE)
    log_message "Submitting job: $Jobid , Constraint Force: $UPDATED_FORCE"
    
    log_message "Sleep for $SLEEPTIME before checking status."
    sleep $SLEEPTIME
    
    # Check the state after waking up
    check_Jobid "$Jobid"
    # Check the status of the job
    check_status "$Jobid"
    
    # Rename npt.gro and update SLURM script
    UPDATE_GRO=npt_"$UPDATED_FORCE".gro

    if [ -f "$CHECKFILE" ]; then
       mv "$CHECKFILE" "$UPDATE_GRO"
       mv md.log md_"$UPDATED_FORCE".log
       log_message "renaming files: $CHECKFILE -> $UPDATE_GRO , also the md.log"
    else
        log_message "Something went wrong; kill nohup PID and exit 1\n"
        nohupFile=nohup.PID
        nohupPID=$(tac "$nohupFile" | grep -m 1 -v '^$')
        kill "$nohupPID"
        exit 1
    fi

    # Update structure path in SLURM script
    sed -i "s/^STRUCTURE=.*/STRUCTURE=.\/$UPDATE_GRO/" "$SLURM_FILE"
    log_message "Starting new job with initital structure: $UPDATE_GRO"
done

if [ -f npt_$DROP_STEP.gro ]; then
    sed -i 's/^MDP_FILE=.*/MDP_FILE=npt_noConstraints.mdp \\/' $SLURM_FILE
    Jobid=$(sbatch --parsable $SLURM_FILE)
    log_message "Submitting final job with id: $Jobid, and sleep 12 hours"
    sleep 12h
    # Check the state after waking up
    check_Jobid "$Jobid"
    # Check the status of the job
    check_status "$Jobid"
fi

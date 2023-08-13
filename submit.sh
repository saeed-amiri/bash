#!/bin/bash

# Usage: bash resubmit_script.sh CHECKFILE

# Initialize variables
REPORT="./RESUBMIT_REPORT"
MAXNAP=15
COUNTER=0

# Check if the CHECKFILE argument is provided
if [ -z "$1" ]; then
    echo "Error: Please provide the CHECKFILE argument."
    echo "Usage: bash resubmit_script.sh CHECKFILE"
    exit 1
fi

CHECKFILE="$1"

# Function to log messages to the REPORT file
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$REPORT"
}

# Function to check the status of the job
check_status() {
    Jobid=$1
    status_variable=$(sacct | grep "$Jobid" | grep standard | awk '{print $6}')
    log_message "status of job $Jobid is $status_variable"

    if [ "$status_variable" == "COMPLETED" ]; then
        log_message "Job completed! Exit!"
        exit 0
    elif [ "$status_variable" == "TIMEOUT" ]; then
        log_message "Job: $Jobid continued as expected."
    elif [ "$status_variable" == "RUNNING" ]; then
        while [ "$status_variable" == "RUNNING" ]; do
            log_message "$Jobid is still running! Waiting for another hour..."
            sleep 1h
            status_variable=$(sacct | grep "$Jobid" | grep standard | awk '{print $6}')
        done
    elif [ "$status_variable" == "FAILED" ]; then
        # Get the last line of the nohup.PID
        log_message "Job failed; kill nohup PID and exit 1"
        nohupFile=nohup.PID
        nohupPID=$(tac "$nohupFile" | grep -m 1 -v '^$')
        kill $nohupPID
        exit 1
    fi
}

check_Jobid(){
        if [ -z "$1" ]; then
            LASTLINE=$(sacct | tail -1 | awk '{print $1}')
            Jobid="${LASTLINE%%.*}"
        fi
}

# Check the CHECKFILE condition initially
if [ ! -f "$CHECKFILE" ]; then
    log_message "Look for file: $CHECKFILE at every step"
else
    log_message "The condition is already satisfied. Job has completed or is not running."
    exit 0
fi

# Submit the initial job and get the Jobid
Jobid_init=$(sbatch --parsable slurm.long_nvt)

# Log the initial job submission details
log_message "Submit nvt job, with jobid: $Jobid_init"
log_message "Sleep for 13 hours before rechecking status."

# Sleep for 13 hours before checking the job status
sleep 13h

check_Jobid $Jobid_init
check_status $Jobid_init

# Loop for resubmission
while [ ! -f "$CHECKFILE" ]; do
    if [ "$COUNTER" -le "$MAXNAP" ]; then
        COUNTER=$(( COUNTER + 1 ))
        log_message "Resubmitting job, COUNTER nr.: $COUNTER"
        log_message "Sleep for 13 hours before rechecking status."

        # Submit the continuation job and get the Jobid
        Jobid=$(sbatch --parsable slurm.continue)

        # Sleep for 13 hours before checking the job status again
        sleep 13h

        # Check the state after waking up
        check_Jobid $Jobid
        # Check the status of the job
        check_status "$Jobid"
    else
        log_message "The number of continued jobs exceeded the maximum allowed. Exiting."
        exit 1
    fi
done

# The CHECKFILE condition is met
log_message "The CHECKFILE condition is now satisfied. Job has completed or is not running."

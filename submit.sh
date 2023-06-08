#! /bin/bash

# Write to both file and stdout
ECHOMESG() {
    for arg in "$@"; do
        echo "$arg" >> "$REPORT"
        echo "$arg"
    done
}

# Kill the nohub job when needed
KILLJOB(){
    REPORT=./RESUBMIT_REPORT  # Report file
    file_path="./nohup.PID"  # Nohup file, to kill in total
    last_line=$(tail -n 1 "$file_path")
    if [[ $last_line =~ ^[0-9]+$ ]]; then
        pid=$(awk '{print $1}' <<< "$last_line")
        if kill -0 "$pid" 2>/dev/null; then
            ECHOMESG "From slurm.long_nvt: Process with PID $pid exists. Killing it..."
            kill -9 "$pid"
        else
            ECHOMESG "From slurm.long_nvt: Process with PID $pid does not exist."
        fi
    else
        ECHOMESG "From slurm.long_nvt: Last line of the file is not a valid PID."
    fi
}
# Continue the job
RUNJOB() {
    local job_name=$1
    local sleep_duration=$2
    ECHOMESG "Starting a new job" \
             "$(date)" \
             "" \
             "Submit nvt job, with jobid: $job_name" \
             "Sleep for $sleep_duration"
    sleep "$sleep_duration"
    ECHOMESG "############################" \
             "Waking up..." \
             "$(date)"
}

# try to resubmit until condition is satisfied
# Make a report file
REPORT=./RESUBMIT_REPORT
true > "$REPORT"
# Check file for continuing the job, usually gro file
CHECKFILE=$1
ECHOMESG "check file is: $CHECKFILE"

# How many times the job may need to be continue (total hours of the simulation divided
# by the sleep time)
MAX_RERUNS = 6
# Run the first run
Jobid=$(sbatch --parsable slurm.long_nvt)
# Run the job
RUNJOB "$Jobid" "13h"

if [ -n "$CHECKFILE" ]; then
    # If the check file is created by the first run, it should not continue
    ECHOMESG "The $CHECKFILE does not exist yet, jobs will continue" \
             "Looking for file: $CHECKFILE at every step"
    COUNTER=1  # Count the number of resubmit
    while [ ! -f "$CHECKFILE" ]; do
        ((COUNTER++))

        if [ $COUNTER -gt $MAX_RERUNS ]; then
            ECHOMESG "COUNTER is greater than $MAX_RERUNS. Exiting script." \
                     "Kill the nohup job: Too many rerun: $COUNTER"
            # Kill the nohub job
            KILLJOB
            exit 1
        fi
        ECHOMESG " "

        Jobid=$(sbatch --parsable slurm.continue)

        RUNJOB "$Jobid" "13h"

    done
else
    ECHOMESG "$CHECKFILE is found..." \
             "Kill the nohup job, a $CHECKFILE is found before continuing the runs"
    # Kill the nohub job
    KILLJOB
fi

# Kill the nohub job
ECHOMESG "Kill the nohup job, Conditions in this script: $0 is satisfied"
KILLJOB
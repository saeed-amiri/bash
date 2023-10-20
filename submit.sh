#!/bin/bash

# Usage: bash resubmit_script.sh CHECKFILE

# Initialize variables
CHECKFILE="$1"
JobName="50VLg"
REPORT="./RESUBMIT_REPORT"
TOPFILE="./topol.top"
JOBIDLIST="./JOBID_LIST"
SLEEPTIME=13h
SNOOZE=1h
MAXNAP=30
COUNTER=0

# Check if the CHECKFILE argument is provided
if [ -z "$1" ]; then
    echo "Error: Please provide the CHECKFILE argument."
    echo "Usage: bash resubmit_script.sh CHECKFILE"
    exit 1
fi

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

# Function to log messages to the REPORT file
log_message() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$REPORT"
}

# Function to check the status of the job
check_status() {
    local Jobid="$1"
    local status_variable
    status_variable=$(sacct | grep "$Jobid" | grep standard | awk '{print $6}')
    log_message "status of job $Jobid is $status_variable"

    if [ "$status_variable" == "COMPLETED" ]; then
        log_message "Job completed! EXIT!"
        exit 0

    elif [ "$status_variable" == "TIMEOUT" ]; then
        local LastStep
        local SlurmFile=slurm-$Jobid.out
        [ -s "$SlurmFile" ] || log_message "The file $SlurmFile is not recognized!\n"
        log_message "Reading $SlurmFile\n"
        LastStep=$(tac "$SlurmFile" |grep "^imb" |head -1)
        log_message "Job: $Jobid continued as expected."
        log_message "Last two MD steps are:\n\t$LastStep\n"

    elif [ "$status_variable" == "RUNNING" ]; then
        while [ "$status_variable" == "RUNNING" ]; do
            log_message "$Jobid is still running! Recheking in $SNOOZE..."
            sleep $SNOOZE
            status_variable=$(sacct | grep "$Jobid" | grep standard | awk '{print $6}')
        done
        check_status "$Jobid"   # Recursive call to check_status

    elif [ "$status_variable" == "FAILED" ]; then
        # Get the last line of the nohup.PID
        log_message "Job failed; kill nohup PID and exit 1"
        local nohupFile=nohup.PID
        local nohupPID
        nohupPID=$(tac "$nohupFile" | grep -m 1 -v '^$')
        kill "$nohupPID"
        exit 1

    elif [ "$status_variable" == "PENDING" ]; then
        log_message "Job still PENDING, sleep for $SLEEPTIME !!!"
        sleep $SLEEPTIME
        check_status "$Jobid"   # Recursive call to check_status
    fi
}

check_Jobid(){
    if [ -z "$1" ]; then
        local LASTLINE
        LASTLINE=$(sacct | grep "$JobName" | tail -1 | awk '{print $1}')
        Jobid="${LASTLINE%%.*}"
    fi
}

# Call the function to check input files
check_includes $TOPFILE

# Make sure of the job name in slurm
for slurm_file in slurm.long_run slurm.continue; do
    sed -i "s/^#SBATCH --job-name.*/#SBATCH --job-name $JobName/" "$slurm_file"
done

log_message "\n\t\tStarting Jobname: $JobName\n"

# Check the CHECKFILE condition initially
if [ ! -f "$CHECKFILE" ]; then
    log_message "Look for file: $CHECKFILE at every step"
else
    log_message "The condition is already satisfied. Job has been terminated!"
    exit 0
fi

if [[ ! -f "npt.tpr" ]]; then
    # Submit the initial job and get the Jobid
    Jobid_init=$(sbatch --parsable slurm.long_nvt)

    # Log the initial job submission details
    log_message "Submit nvt job, with jobid: $Jobid_init"
    log_message "Sleep for $SLEEPTIME hours before checking the status..."

    echo -e "0\t$Jobid_init" > $JOBIDLIST

    # Sleep for 13 hours before checking the job status
    sleep $SLEEPTIME

    check_Jobid "$Jobid_init"
    check_status "$Jobid_init"
else
    log_message "\n\t\tSomething happend!\n"
fi

# Loop for resubmission
while [ ! -f "$CHECKFILE" ]; do
    if [ "$COUNTER" -le "$MAXNAP" ]; then
        COUNTER=$(( COUNTER + 1 ))

        # Submit the continuation job and get the Jobid
        Jobid=$(sbatch --parsable slurm.continue)

        echo -e "$COUNTER\t$Jobid" >> $JOBIDLIST
        
        log_message "Resubmitting job: $Jobid , COUNTER nr.: $COUNTER"
        log_message "Sleep for $SLEEPTIME hours before checking the status..."

        # Sleep for SLEEPTIME before checking the job status again
        sleep $SLEEPTIME

        # Check the state after waking up
        check_Jobid "$Jobid"
        # Check the status of the job
        check_status "$Jobid"
    else
        log_message "The number of continued jobs exceeded the maximum allowed numbers. EXIT!."
        exit 1
    fi
done

# The CHECKFILE condition is met
log_message "The CHECKFILE condition is now satisfied. Job has been terminated!"

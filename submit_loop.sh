#!/bin/bash

# Usage: bash submit_loop.sh 
# This script, submit_loop.sh, is a Bash script designed to automate the submission
# and monitoring of jobs in a high-performance computing (HPC) environment. It's
# specifically tailored for a workflow that involves two types of jobs: "update"
# jobs and "em" jobs. The script submits these jobs in a loop, checks their status,
# and performs certain actions based on the status of the jobs.

# The script begins by initializing a number of variables, including file names, sleep
# times, and a counter. It then checks if the INITIALIONS argument is provided when the
# script is run. If not, it prints an error message and exits.

# The script defines several functions:

# check_file_exists(): This function checks if a specified file exists and prints a
# message accordingly.
# check_includes(): This function checks for #include statements in a file and
# verifies the existence of the included files.
# log_message(): This function logs messages to a report file, with a timestamp.
# check_status(): This function checks the status of a job using the sacct command,
# which is part of the Slurm workload manager commonly used on HPC systems.
# Depending on the status of the job ("COMPLETED", "TIMEOUT", "RUNNING", "FAILED",
# "PENDING"), it performs different actions, such as logging messages, sleeping, or
# exiting the script.
# check_Jobid(): This function checks if a Jobid is provided. If not, it retrieves
# the last Jobid from the sacct command.
# The main loop of the script submits "update" and "em" jobs in turn, up to a maximum
# number of iterations (MaxLoop). For each job, it submits the job using the sbatch
# command, logs the job ID, sleeps for a certain amount of time, checks the job status,
# and performs actions based on the status. If the job completes successfully, it backs
# up certain files, renames the updated files, and updates a parameter in a file. If the
# job fails, it logs an error message and exits the script. The loop continues until the
# maximum number of iterations is reached.

# submit_update_job(): This function submits an "update" job, logs the job ID, sleeps
# for a certain amount of time, checks the job status, and performs actions based on
# the status. If the job completes successfully, it backs up certain files, renames
# the updated files, and updates a parameter in a file. If the job fails, it logs an
# error message and exits the script.
# process_files(): This function backs up the files and renames the updated files. It
# also updates a parameter in a file.
# submit_em_job(): This function submits an "em" job, logs the job ID, sleeps for a
# certain amount of time, checks the job status, and performs actions based on the
# status. If the job completes successfully, it backs up certain files, renames the
# updated files, and updates a parameter in a file. If the job fails, it logs an
# error message and exits the script.

# Initialize variables
INITIALIONS="$1"
JobName="5OdaUpEm"
Report="./RESUBMIT_REPORT"
JobIdList="./JOBID_LIST"
SLEEPTIME=8m
SNOOZE=2m
IncrementIons=5
MaxLoop=6
COUNTER=0

# Input files
InitStructure="em.gro"
UpdateFile="update_param"
TopFile="topol.top"
IndexFile="index.ndx"
MdpFile="em.mdp"
EmSlurmFile="slurm.em"
UpdateSlurmFile="slurm.update"
ItpFile="APT_COR.itp"

# Update output files
UpdatePassGro="updated_system.gro"
UpdatePassTop="topol_updated.top"
UpdatePassItp="APT_COR_updated.itp"

# Check if the INITIALIONS argument is provided
if [ -z "$1" ]; then
    echo "Error: The initial ions number is missing."
    echo "Please provide the INITIALIONS argument."
    echo "Usage: bash submit_loop.sh INITIALIONS"
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
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$Report"
}

# Function to check the status of the job
check_status() {
    local Jobid="$1"
    local status_variable
    status_variable=$(sacct | grep "$Jobid" | grep standard | awk '{print $6}')
    log_message "status of job $Jobid is $status_variable"

    if [ "$status_variable" == "COMPLETED" ]; then
        log_message "Job completed!"

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

submit_update_job() {
    local Counter="$1"
    # Submit the update job and get the Jobid
    local Jobid=$(sbatch --parsable "$UpdateSlurmFile")
    echo -e "Update $Counter\t$Jobid" >> $JobIdList
    log_message "Update job: $Jobid , Counter nr.: $Counter"
    log_message "Sleep for $SLEEPTIME before checking the status..."
    sleep "$SLEEPTIME"
    # Check the state after waking up
    check_Jobid "$Jobid"
    # Check the status of the job
    check_status "$Jobid"
    
    #  Check if the update job is completed
    if [ ! -f $UpdatePassGro ]; then
        log_message "The file $UpdatePassGro does not exist. Update Failed! EXIT!"
        exit 1
    fi
}

process_files() {
    # Backup the files and rename the updated files
    local Counter="$1"
    local CLA="$2"
    # backup files
    mv $InitStructure $InitStructure.bak_$Counter
    mv $TopFile $TopFile.bak_$Counter
    mv $IndexFile $IndexFile.bak_$Counter
    mv $ItpFile $ItpFile.bak_$Counter
    # rename the updated files
    mv $UpdatePassGro $InitStructure
    mv $UpdatePassTop $TopFile
    mv $UpdatePassItp $ItpFile
    # Update CLA number in topol file
    sed -i "/^CLA/c\CLA    $CLA" $TopFile
}

submit_em_job() {
    # Submit the em job and get the Jobid
    local Counter="$1"
    local Jobid=$(sbatch --parsable "$EmSlurmFile")
    echo -e "Em $Counter\t$Jobid" >> $JobIdList
    log_message "Em job: $Jobid , Counter nr.: $Counter"
    log_message "Sleep for $SLEEPTIME before checking the status..."
    sleep "$SLEEPTIME"
    # Check the state after waking up
    check_Jobid "$Jobid"
    # Check the status of the job
    check_status "$Jobid"
    
    #  Check if the update job is completed
    if [ ! -f $InitStructure ]; then
        log_message "The file $InitStructure does not exist. Em Failed! EXIT!"
        exit 1
    fi
}

check_file_exists "$InitStructure"
check_file_exists "$UpdateFile"
check_file_exists "$TopFile"
check_file_exists "$IndexFile"
check_file_exists "$MdpFile"
check_file_exists "$EmSlurmFile"
check_file_exists "$UpdateSlurmFile"
check_file_exists "$ItpFile"
check_includes "$TopFile"

while [ $COUNTER -lt $MaxLoop ]; do
    # Submit the update job and get the Jobid
    submit_update_job $COUNTER

    # process the files
    INITIALIONS=$((INITIALIONS+IncrementIons))
    process_files $COUNTER $INITIALIONS
    echo "Preparation for the em job..."
    echo "Make index file..."
    echo "q" | gmx_mpi make_ndx -f $InitStructure -o $IndexFile
    # Submit the em job and get the Jobid
    submit_em_job $COUNTER
    echo "Em job $COUNTER is done!"
    echo " "
    ((COUNTER++))
done

rm *.debug
rm step*
rm \#*

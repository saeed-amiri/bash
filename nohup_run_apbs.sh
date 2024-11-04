#!/bin/bash

echo "$(date)" >> nohup_apbs.PID
echo "Hostname: $(hostname)" >> nohup_apbs.PID
echo "Submitted script: $0" >> nohup_apbs.PID
echo "PID of the nohup process:" >> nohup_apbs.PID
nohup bash run_apbs.sh > run_apbs.log 2>&1 &
echo $! >> nohup_apbs.PID

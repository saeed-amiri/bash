#!/bin/bash

echo "$(date)" >> nohup_gro2pqr.PID
echo "Hostname: $(hostname)" >> nohup_gro2pqr.PID
echo "Submitted script: $0" >> nohup_gro2pqr.PID
echo "PID of the nohup process:" >> nohup_gro2pqr.PID
nohup bash gro2pqr.sh > my_gro2pqr.log 2>&1 &
echo $! >> nohup_gro2pqr.PID

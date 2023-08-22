#! /bin/bash

echo `date` >> nohup.PID
echo "submit $0 " >> nohup.PID
echo "PID of the nohup is:" >> nohup.PID
nohup bash submit.sh nvt.gro > my.log 2>&1 &
echo $! >> nohup.PID

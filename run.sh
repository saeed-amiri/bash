#! /bin/bash

echo -e "\n" >> nohup.PID
echo `date` >> nohup.PID
echo "hostname: $(hostname)" >> nohup.PID
echo "submit $0 " >> nohup.PID
echo "PID of the nohup is:" >> nohup.PID
nohup bash submit.sh npt.gro > my.log 2>&1 &
echo $! >> nohup.PID

#!/bin/bash
{
  date
  echo "submit $0"
  echo "PID of the nohup is:"
  nohup bash submit.sh nvt.gro
  echo $!
} >> nohup.PID 2>&1

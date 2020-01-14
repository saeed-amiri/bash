#!/usr/bin/env bash

prepare.py -v RAN -f RUNS_RAN
i=0
for line in $(cat RUNS_RAN); do
  cd $line
    cp ../RUNS_KICK .
    mv PARAM PARAM.base
    prepare.py -v KICK -f RUNS_KICK
    for k in $(cat RUNS_KICK);do 
      cd $k
        eval.py ../../base.lmp 
        cp ../../slrun ./
        sbatch slrun
        i=$((i+1))
      cd ..
    done
  cd ..
done
echo $i

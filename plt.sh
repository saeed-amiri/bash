#!/usr/bin/env bash
for i in 6424 4951;do
    cd $i
        for k in 1.2 1 0.8 0.5 0.1 2 5 10;do
            cd $k
                mkdir plot
                for j in $(seq 0.1 0.1 2.0) ;do 
                    cd $j
                        read_lammps_LOG.py LOG.0 0 C_VEL[1] C_VEL[2] C_DSP[1] C_DSP[2] C_TEMP C_KES
                        cp SLOG.0 ../plot/SLOG_$j
                    cd ..
                done
                cd plot
                    cp ../PARAM.base .
                    sed -i '1 i\#T=0' PARAM.base
                    fit_slog.py $i
                cd ..
            cd ..
        done
    cd ..
done

#!/usr/bin/csh
HERE=$(pwd)
for dir in $(ls -d */*); do
    if [ -d $dir ]; then
        cd $dir
            if [ -d 'rerun_energy' ]; then
                cd 'rerun_energy'
                pwd
                rm 'energy.xvg'
                for i in {1..100}; do
                    echo "$i" | gmx_mpi energy -f npt_rerun.edr
                    if [ -f 'energy.xvg' ]; then
                        LINE=$(sed -n -e 24p energy.xvg)
                        TITLE1=$(echo $LINE | cut -d'"' -f 2)
                        TITLE=$(echo $TITLE1|sed "s/:/_/g")
                        mv energy.xvg $TITLE.xvg
                    else
                        break
                    fi
                done 
                echo
            fi
        cd $HERE
    fi
done

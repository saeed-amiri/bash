#!/bin/bas

# unwrap traj from 16Nov no nanoparticles

unwrap_traj(){
    local dir="$1"Oda
    local sourceDir
    local runDir
    local dirCount

    mkdir "$dir" || { echo "The dir $dir exist!"; }
    pushd "$dir" || exit 1

    runDir=$(find . -maxdepth 1 -type d -name "*${COMTRAJ}" -print -quit)
    if [[ -z "$runDir" ]]; then
        runDir="${COMTRAJ}"
        existDirs=( */ )
        largest_integer=6
        for dir_name in "${existDirs[@]}"; do
            if [[ "$dir_name" =~ ^([0-9]+)_ ]]; then
                existing_integer="${BASH_REMATCH[1]}"
                if ((existing_integer > largest_integer)); then
                    largest_integer="$existing_integer"
                fi
            fi
            echo -e "Exiting loop for dir: $dir_name"
        done

        ((largest_integer++))
        runDir="${largest_integer}_${runDir}"

        mkdir "$runDir" || exit 1
    else
        echo "com dir is already exist"
    fi

    pushd $runDir || exit 1
    
    # rm  com_pickle || { echo "com_pickle do not exist!"; }
    
    sourcePath="$PARENTDIR"/"$dir"
    sourceDir=$(find $sourcePath -maxdepth 1 -type d -name *${SOURCEDIR} -print -quit)
    
    cp "$sourceDir"/topol.top .
    
    for structre in gro trr; do
        echo 0 | gmx_mpi trjconv -s "$sourceDir"/npt.tpr -f "$sourceDir"/npt."$structre" \
                                  -o nojump_unwrap."$structre" -pbc nojump
    done
    for structre in gro trr; do
        echo 0 | gmx_mpi trjconv -s "$sourceDir"/npt.tpr -f nojump_unwrap."$structre" \
                                 -o whole_nojump_unwrap."$structre" -pbc whole
    done

    popd
    popd
}

get_traj(){
    local dir="$1"Oda
    local existDirs
    local existing_integer
    local largest_integer
    local strucDir
    local runDir
    local nptTrr    
    local nptTpr
    local nptNdx
    local outPutOptions
    local dir_name

    pushd "$dir" || exit 1

    runDir=$(find . -maxdepth 1 -type d -name "*${ANALYZENPTRAJ}" -print -quit)
    if [[ -z "$runDir" ]]; then
        runDir="${ANALYZENPTRAJ}"
        existDirs=( */ )
        largest_integer=0
        for dir_name in "${existDirs[@]}"; do
            if [[ "$dir_name" =~ ^([0-9]+)_ ]]; then
                existing_integer="${BASH_REMATCH[1]}"
                if ((existing_integer > largest_integer)); then
                    largest_integer="$existing_integer"
                fi
            fi
            echo -e "Exiting loop for dir: $dir_name"
        done

        ((largest_integer++))
        runDir="${largest_integer}_${runDir}"

        mkdir "$runDir" || exit 1
    else
        echo "traj dir is already exist"
    fi
    pushd "$runDir" || exit 1
    
    sourcePath="$PARENTDIR"/"$dir"
    strucDir=$(find $sourcePath -maxdepth 1 -type d -name *${SOURCEDIR} -print -quit)
    
    nptTrr="$strucDir/npt.trr"
    nptTpr="$strucDir/npt.tpr"
    nptNdx="$strucDir/index.ndx"

    outPutOptions=(
        "ob"    # Box
    )

    for out_put in ${outPutOptions[@]}; do
        echo "0" | gmx_mpi traj -f "$nptTrr" \
                                 -s "$nptTpr" \
                                 -n "$nptNdx" \
                                 -com yes \
                                 -pbc yes \
                                 -nojump yes \
                                 -"$out_put"
    done
    
    cp $nptNdx . || { echo "Index exist!"; }
}

#  Dirs names:
SOURCEDIR="For100ns"
ANALYZENPTRAJ="analysisNpTrajAfter100ns"
COMTRAJ="com_trajAfter100ns"

PARENTDIR="/scratch/projects/hbp00076/PRE_DFG_16Nov23/runs/no_nanoparticle"

dirs=( "5" "10" "15" "20" "50" "100" "150" "200" "300" )
# dirs=( "5" )

export PARENTDIR SOURCEDIR COMTRAJ ANALYZENPTRAJ
export -f unwrap_traj get_traj
case $1 in
    'unwrap')
    parallel unwrap_traj ::: "${dirs[@]}"
    ;;
    'get_traj')
    parallel get_traj ::: "${dirs[@]}"
esac


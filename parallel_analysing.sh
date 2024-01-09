#!/bin/bash

# To analysing simple things with gromacs itself

pull_repository(){
    local repo=$1
    pushd "/scratch/projects/hbp00076/MyScripts/$repo" || exit 1
        git pull origin main
    popd || exit 1
}

get_density(){
    local dir="$1"Oda
    local runDir="$DENSITY"
    local tmpFile='density.xvg'
    local sourceDir
    local titleLine
    local titleTmp
    local title
    
    pushd "$dir" || exit 1


    runDir=$(find . -maxdepth 1 -type d -name "*${runDir}" -print -quit)
    if [[ -z "$runDir" ]]; then
        runDir="$DENSITY"
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

    sourceDir=$(find .. -maxdepth 1 -type d -name "*${SOURCEDIR}" -print -quit)
    
    if [ -f $tmpFile ]; then
        rm $tmpFile
    fi
    
    local startFrame=0  # Variable to specify the starting frame
    
    # SOL: 2
    # D10: 5
    # ODN: 6
    # CLA: 7
    # POT: 8
    # COR: 9
    # APT: 10
    # COR_APT: 11
    groupIds=( '2' '5' '6' '7' '8' '9' '10' '11' )
    for group in "${groupIds[@]}"; do
        echo "$group" | gmx_mpi density -s "$sourceDir"/npt.tpr -f "$sourceDir"/npt.xtc \
                                        -n "$sourceDir"/index.ndx -b "$startFrame" -o "$tmpFile"
        if [ -f "$tmpFile" ]; then
            titleLine=$(sed -n -e 24p $tmpFile)
            titleTmp=$(echo $titleLine | cut -d'"' -f 2)
            title=$(echo $titleTmp | sed "s/:/_/g")
            mv "$tmpFile" "$title".xvg
        else
            break
        fi
    done
    popd
}

get_tension() {
    local parentDir
    local dir="$1"Oda
    local Oda="$1"
    local runDir=""
    local sourceDir
    local tmpFile='tension.xvg'
    local logFile='tension.log'
    local gamma
    
    parentDir=$(pwd)
    if [[ $1 == "noOdaNp" || $1 == "zero" ]]; then
        Oda=0
    fi
    touch $logFile
    pushd $dir || exit 1

    runDir=$(find . -maxdepth 1 -type d -name "*${TENSION}" -print -quit)
    if [[ -z "$runDir" ]]; then
        runDir="${TENSION}"
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

    sourceDir=$(find .. -maxdepth 1 -type d -name "*${SOURCEDIR}" -print -quit)

    if [[ -f "$parentDir"/"$logFile" ]]; then
        rm "$parentDir"/"$logFile"
    fi

    local startFrame=0  # Variable to specify the starting frame
    gamma=$(echo "43"| gmx_mpi energy -f "$sourceDir"/npt.edr -s "$sourceDir"/npt.tpr -o "$tmpFile" -b "$startFrame" | \
                 grep '#Surf'|awk -F ' ' '{print $2}') 
    echo "$dir $Oda $gamma" >> "$parentDir"/"$logFile"
}

get_com_plumed(){
    local parentDir
    local dir="$1"Oda
    local Oda="$1"
    local pwDir
    local count
    local dirCount
    local plumedInput="plumed.dat"
    pushd $dir || exit 1
    dirCount=$(find . -maxdepth 1 -type d -regex './[0-9].*' | wc -l)

    pwDir=$(find . -maxdepth 1 -type d -name "*${PLUMEDCOM}" -print -quit)
    if [[ -z "$pwDir" ]]; then
        pwDir="${PLUMEDCOM}"
        dirCount=$(find . -maxdepth 1 -type d -regex './[0-9].*' | wc -l)
        count=1
        if [[ $dirCount -eq 0 ]]; then
            pwDir="${count}_${pwDir}"
        else
            for dir in */; do
                if [[ $dir =~ ^[0-9] ]]; then
                    ((count++))
                fi
            done
            pwDir="${count}_${pwDir}"
        fi
        mkdir "$pwDir" || exit 1
    else
        echo "com directory exist"
    fi
    pushd $pwDir || exit 1

    sourceDir=$(find .. -maxdepth 1 -type d -name "*${SOURCEDIR}" -print -quit)
    cp "$sourceDir"/index.ndx .
    cat > "$plumedInput" << EOF
# Define the group from the index file
GROUPA: GROUP NDX_FILE=index.ndx NDX_GROUP=COR_APT
# Calculate the center of mass of the defined group
c1: CENTER ATOMS=GROUPA
# Print the center of mass to an output file
p: POSITION ATOM=c1
PRINT ARG=p.x,p.y,p.z FILE=plumed_output.dat
EOF
    plumed driver --mf_trr "$sourceDir"/npt.trr --plumed "$plumedInput"
}

unwrap_traj(){
    local dir="$1"Oda
    local sourceDir
    local runDir
    local dirCount
    pushd $dir || exit 1

    runDir=$(find . -maxdepth 1 -type d -name "*${COMTRAJ}" -print -quit)
    if [[ -z "$runDir" ]]; then
        runDir="${COMTRAJ}"
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
        echo "com dir is already exist"
    fi
    pushd $runDir || exit 1
    rm *.trr *.gro com_pickle || { echo "gro and/or trr and/or com_pickle do not exist!"; }
    rm .unwrap*
    sourceDir=$(find .. -maxdepth 1 -type d -name *${SOURCEDIR} -print -quit)
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

get_frames() {
    local dir="$1"Oda
    local runDir
    local parentDir
    local jobName="$1"Ana
    local slurmName
    local slurmFile
    slurmName="slurm.frames"
    parentDir=$(pwd)

    pushd $dir || exit 1

    runDir=$(find . -maxdepth 1 -type d -name "*${COMTRAJ}" -print -quit)
    if [[ -z "$runDir" ]]; then
        runDir="${COMTRAJ}"
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
        echo "com dir is already exist"
    fi
    pushd "$runDir" || exit 1
    slurmFile=$(find $parentDir -type f -name $slurmName -print -quit)
    cp "$slurmFile" . || exit 1
    sed -i "s/^#SBATCH --job-name.*/#SBATCH --job-name $jobName/" "$slurmName"
    sbatch "$slurmName"
    popd
}

get_rdf() {
    local dir="$1"Oda
    local pwDir
    local sourceDir
    local dirCount
    pushd $dir || exit 1

    pwDir=$(find . -maxdepth 1 -type d -name "*${RDF}" -print -quit)
    if [[ -z "$pwDir" ]]; then
        pwDir="${RDF}"
        dirCount=$(find . -maxdepth 1 -type d -regex './[0-9].*' | wc -l)
        local count=1
        if [[ $dirCount -eq 0 ]]; then
            pwDir="${count}_${pwDir}"
        else
            for dir in */; do
                if [[ $dir =~ ^[0-9] ]]; then
                    ((count++))
                fi
            done
            pwDir="${count}_${pwDir}"
        fi
        mkdir "$pwDir" || exit 1
    else
        echo "rdf directory exist"
    fi
    cd "$pwDir"

    sourceDir=$(find .. -maxdepth 1 -type d -name "*${SOURCEDIR}" -print -quit)
 
    local referencePosition="whole_res_com"
    local refResisue="APT"
    local firstFrame=120000
    local outRdf
    local outCdf
 
    local tragetResidues=( "ODN" "CLA" "POT" )
    for res in "${tragetResidues[@]}"; do
        outRdf=rdf_"$res".xvg
        outCdf=cdf_"$res".xvg
        gmx_mpi rdf -f "$sourceDir"/npt.trr \
                    -s "$sourceDir"/npt.tpr \
                    -selrpos "$referencePosition" \
                    -ref "$refResisue" \
                    -sel "$res" \
                    -b "$firstFrame" \
                    -o $outRdf \
                    -cn $outCdf
    done
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

    strucDir=$(find ../ -type d -name "*${SOURCEDIR}" -print -quit)
    nptTrr="$strucDir/npt.trr"
    nptTpr="$strucDir/npt.tpr"
    nptNdx="$strucDir/index.ndx"

    outPutOptions=(
        "ox"    # Coordinate
        "ov"    # Velocity
        "of"    # Forces
        "ob"    # Box
        "ekt"   # Translational energy
        "ekr"   # Rotationsl energy
        "vd"    # veldlist
        "av"    # all_veloc
        "af"    # all_forces
    )

    for out_put in ${outPutOptions[@]}; do
        echo "11" | gmx_mpi traj -f "$nptTrr" \
                                 -s "$nptTpr" \
                                 -n "$nptNdx" \
                                 -com yes \
                                 -pbc yes \
                                 -nojump yes \
                                 -"$out_put"
    done
}

get_bootstraps(){
    local dir="$1"Oda
    local runDir
    local pyPath
    pushd "$dir" || exit 1

    runDir=$(find . -maxdepth 1 -type d -name "*${TENSION}" -print -quit)
    pushd "$runDir" || { echo "Tension directory not found"; exit 1; }
    
    pyPath=/scratch/projects/hbp00076/MyScripts/GromacsPanorama/src
    python "$pyPath/module2_statistics/bootstrap_sampler.py" tension.xvg
    
    popd
}

np_interface_analysis() {
    local dir="$1"Oda
    local runDir
    local comDir
    local coordDir
    local pyPath="/scratch/projects/hbp00076/MyScripts/GromacsPanorama/src"
    local figDir="figs"
    local slurmName="slurm.read_com"
    local slurmFile
    local JobName="$1"ComAna
    local pyCommand

    pushd "$dir" || exit 1

    runDir=$(find . -maxdepth 1 -type d -name "*${NPINTERFACEANALYZE}" -print -quit)
    if [[ -z "$runDir" ]]; then
        runDir="${NPINTERFACEANALYZE}"
        existDirs=( */ )
        largest_integer=0
        for dir_name in "${existDirs[@]}"; do
            if [[ "$dir_name" =~ ^([0-9]+)_ ]]; then
                existing_integer="${BASH_REMATCH[1]}"
                if ((existing_integer > largest_integer)); then
                    largest_integer="$existing_integer"
                fi
            fi
            echo -e "Exiting loop for dir: ${dir_name}"
        done

        ((largest_integer++))
        runDir="${largest_integer}_${runDir}"

        mkdir "$runDir" || { echo "Failed to create directory ${runDir}."; return 1; }
    else
        echo "${runDir} dir is already exist"
    fi
    pushd "$runDir" || exit 1
    
    coordDir=$(find .. -maxdepth 1 -type d -name "*${ANALYZENPTRAJ}" -print -quit)
    cp "${coordDir}/coord.xvg" . || { echo "The coord.xvg does not exist!"; return 1; }

    comDir=$(find .. -maxdepth 1 -type d -name "*${COMTRAJ}" -print -quit)
    cp "${comDir}/topol.top" . || { echo "Failed to copy topol file."; return 1; }

    slurmFile=$(find ../.. -maxdepth 1 -type f -name "${slurmName}" -print -quit)
    cp $slurmFile .
    sed -i "s/^#SBATCH --job-name.*/#SBATCH --job-name $JobName/" "$slurmName"

    pyCommand="python ${pyPath}/module3_analysis_aqua/trajectory_aqua_analysis.py ${comDir}/com_pickle" 
    sed -i "$ a ${pyCommand}" "$slurmName" || { echo "Failed to add command to script."; return 1; }

    cat <<EOL >> "$slurmName"
figDir='figs'
if [[ -d "\$figDir" ]]; then
    rm -rf "\$figDir"
fi

mkdir "\$figDir"
mv ./*.png "\$figDir"/ || { echo "Unable to move the figs to \${figDir}"; return 1; }
EOL
    sbatch "$slurmName"

    popd || exit 1

}

# Dirs names:
SOURCEDIR="npt_dropRestrainsAfterEm16"

ANALYZENPTRAJ="analysisNpTraj"
NPINTERFACEANALYZE="NpInterfaceAnalysis"
COMTRAJ="com_traj"
DENSITY="density"
TENSION="tension"
PLUMEDCOM="plumed_com"
RDF="rdf"



export SOURCEDIR DENSITY COMTRAJ TENSION ANALYZENPTRAJ RDF PLUMEDCOM NPINTERFACEANALYZE
export -f get_density get_tension get_com_plumed unwrap_traj get_frames get_rdf get_traj get_bootstraps
export -f np_interface_analysis

# dirs=( "zero" "15" "20" )
dirs=( "200" )
# dirs=( "10" "15" "20" "50" "100" "150" "200" )

case $1 in
    'density')
        parallel get_density ::: "${dirs[@]}"
    ;;
    'tension')
        parallel get_tension ::: "${dirs[@]}"
    ;;
    'plumed')
        parallel get_com_plumed ::: "${dirs[@]}"
    ;;
    'unwrap')
        parallel unwrap_traj ::: "${dirs[@]}"
    ;;
    'frames')
        pull_repository GromacsPanorama || exit 1
        parallel get_frames ::: "${dirs[@]}"
    ;;
    'rdf')
        parallel get_rdf ::: "${dirs[@]}"
    ;;
    'get_traj')
        parallel get_traj ::: "${dirs[@]}"
    ;;
    'boots')
        parallel get_bootstraps ::: "${dirs[@]}"
    ;;
    'np_analysis')
        pull_repository GromacsPanorama || exit 1
        parallel np_interface_analysis ::: "${dirs[@]}"
    ;;
    *)
        echo -e "Invalid argument. Please use 'density', 'tension', 'plumed', 'unwrap', 'frames', 'rdf',\
                 'get_traj', 'boots' 'np_analysis' \n"
esac

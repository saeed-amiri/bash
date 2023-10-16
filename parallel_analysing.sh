#!/bin/bash

# To analysing simple things with gromacs itself

get_density(){
    local dir="$1"Oda
    local pwDir="density"
    local tmpFile='density.xvg'
    local sourceDir
    local titleLine
    local titleTmp
    local title
    
    pushd "$dir" || exit 1
    mkdir "$pwDir"
    pushd "$pwDir" || exit 1

    sourceDir=$(find .. -maxdepth 1 -type d -name '*after*Long300ns' -print -quit)
    
    if [ -f $tmpFile ]; then
        rm $tmpFile
    fi
    
    local startFrame=200  # Variable to specify the starting frame
    
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
        echo "$group" | gmx_mpi density -s "$sourceDir"/npt.tpr -f "$sourceDir"/npt.trr \
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
    local pwDir="tension"
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
    mkdir "$pwDir"
    pushd "$pwDir" || exit
    sourceDir=$(find .. -maxdepth 1 -type d -name '*after*UpAveLong300ns' -print -quit)
    if [[ -f "$parentDir"/"$logFile" ]]; then
        rm "$parentDir"/"$logFile"
    fi
    local startFrame=2000  # Variable to specify the starting frame
    gamma=$(echo "43"| gmx_mpi energy -f "$sourceDir"/npt.edr -s "$sourceDir"/npt.tpr -o "$tmpFile" -b "$startFrame" | \
                 grep '#Surf'|awk -F ' ' '{print $2}') 
    echo "$dir $Oda $gamma" >> "$parentDir"/"$logFile"
}

get_com_plumed(){
    local parentDir
    local dir="$1"Oda
    local Oda="$1"
    local pwDir="plumed_com"
    local plumedInput="plumed.dat"
    pushd $dir || exit 1
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
    
    mkdir "$pwDir"|| { echo "$runDir directory exists!"; return; }
    pushd $pwDir || exit 1

    sourceDir=$(find .. -maxdepth 1 -type d -name '*after*UpAveLong300ns' -print -quit)
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
    local pwDir="com_traj"
    local dirCount

    pushd $dir || exist 1

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
    mkdir $pwDir || exit 1
    pushd $pwDir || exit 1
    sourceDir=$(find .. -maxdepth 1 -type d -name '*after*UpAveLong300ns' -print -quit)
    for structre in gro trr; do
        echo 0 | gmx_mpi trjconv -s "$sourceDir"/npt.tpr -f "$sourceDir"/npt."$structre" -o unwrap."$structre" -pbc whole
    done
    popd
}

export -f get_density get_tension get_com_plumed unwrap_traj

# dirs=( "5" )
dirs=( "5" "15" "20" "200" )
# dirs=( "zero" "5" "15" "20" "50" "100" "150" )

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
    *)
        echo -e "Invalid argument. Please use 'density', 'tension', 'plumed', 'unwrap' \n"
esac

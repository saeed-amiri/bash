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
    if [[ $1 == "noOdaNp" ]]; then
        dir="$1"
    fi
    pushd "$dir" || exit 1
    if [[ ! -d "$pwDir" ]]; then
        mkdir "$pwDir"
    fi
    pushd "$pwDir" || exit 1

    sourceDir=$(find .. -maxdepth 1 -type d -name '*after*Long300ns' -print -quit)
    echo "SOURCEDIR IS    $sourceDir"
    
    if [ -f $tmpFile ]; then
        rm $tmpFile
    fi
    
    local startFrame=200000  # Variable to specify the starting frame
    
    # SOL: 2
    # CLA: 5
    # ODN: 6
    # POT: 7
    # D10: 8
    groupIds=( '2' '5' '6' '7' '8' )
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
    if [[ $1 == "noOdaNp" ]]; then
        dir="$1"
        Oda=0
    fi
    touch $logFile
    pushd $dir || exit 1
    mkdir "$pwDir"
    pushd "$pwDir" || exit
    
    sourceDir=$(find .. -maxdepth 1 -type d -name '*afterNpt*Long300ns' -print -quit)
    local startFrame=2000  # Variable to specify the starting frame
    gamma=$(echo "42"| gmx_mpi energy -f "$sourceDir"/npt.edr -s "$sourceDir"/npt.tpr -o "$tmpFile" -b "$startFrame" | \
                 grep '#Surf'|awk -F ' ' '{print $2}') 
    echo "$dir $Oda $gamma" >> "$parentDir"/"$logFile"
}

export -f get_density get_tension

# dirs=( "5" )
dirs=("noOdaNp" "5" "10" "15" "20" "50" "100" "150" "200" "300")

case $1 in
    'density')
        parallel get_density ::: "${dirs[@]}"
    ;;
    'tension')
        parallel get_tension ::: "${dirs[@]}"
    ;;
    *)
        echo -e "Invalid argument. Please use 'density', 'tension', \n"
esac

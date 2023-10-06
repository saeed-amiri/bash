#!/bin/bash

# To analysing simple things with gromacs itself

get_density(){
    local dir="$1"Oda
    local pwDir="density"
    local tmpFile='density.xvg'
    local titleLine
    local titleTmp
    local title
    pushd "$dir" || exit 1
    mkdir "$pwDir"
    pushd "$pwDir" || exit 1

    local sourceDir
    sourceDir=$(find .. -maxdepth 1 -type d -name '*4_npt_afterNpt3Long300ns' -print -quit)
    
    if [ -f $tmpFile ]; then
        rm $tmpFile
    fi
    local startFrame=200000000  # Variable to specify the starting frame
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

export -f get_density

dirs=( "10" )

case $1 in
    'density')
        parallel get_density ::: "${dirs[@]}"
    ;;
    *)
        echo -e "Invalid argument. Please use 'density', \n"
esac

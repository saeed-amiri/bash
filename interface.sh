#! /bin/bash

# prepare OUTPUT file 
    OUTFILE=system.lt
    >$OUTFILE
    
# remove previous structure
    DATAFILE=system.data
    if [[ -f $DATAFILE ]]; then rm $DATAFILE; fi

function WRITE_BOX ( ) {
    # WRITE_BOX $NX $NXW $NY $NZ decane spce_oplsaa

    TAB=$( printf "\t" )
    XHI=$(echo $1 $2 $XLO $LENGTH  | awk '{printf "%8.5f\n",$1*($4-$3) + ($2*$4/4)}')
    echo $0 $1 $2 $XLO $LENGTH $XHI
    YHI=$(echo $WIDTH $3 $YLO | awk '{printf "%8.5f\n",($1*$2)-$3}')
    ZHI=$(echo $WIDTH $4 $ZLO | awk '{printf "%8.5f\n",($1*$2)-$3}')
    # BOTTOM UP
        sed -i "1 i\ "  $OUTFILE
        sed -i "1 i\ "  $OUTFILE
        sed -i '1i }' $OUTFILE
        sed -i "1 i\ ${TAB} ${ZLO}${TAB}${TAB}${ZHI}${TAB} zlo${TAB}${TAB}zhi"  $OUTFILE
        sed -i "1 i\ ${TAB} ${YLO}${TAB}${TAB}${YHI}${TAB}ylo${TAB}${TAB}yhi"  $OUTFILE
        sed -i "1 i\ ${TAB} ${XLO}${TAB}${TAB}${XHI}${TAB}xlo${TAB}${TAB}xhi"  $OUTFILE
        sed -i "1 i\write_once(\"Data Boundary\") { "  $OUTFILE
        sed -i "1 i\# Periodic boundary conditions: "  $OUTFILE
        sed -i "1 i\ "  $OUTFILE
        sed -i "1 i\import \"$5.lt\"  # <- defines the \"$5\" molecule type. "  $OUTFILE
        sed -i "1 i\import \"$6.lt\"  # <- defines the \"$6\" molecule type. "  $OUTFILE
}


function WRITE_MOL( ) {
    # calculating number of the molecules and number of atoms
        NMOLS=$(echo $1 $2 $3 | awk '{printf "%d\n", $1*$2*$3}')
        LENGTH=12.53322
        if [[ $4 == "Decane" ]] ; then
            # CHAIN length and width of Decane
                XVEC=$(echo $LENGTH  $XLO | awk '{printf "%8.5f\n", $1-$2}' )
                NBASE=32
        elif [[ $4 == 'Water' ]]; then
            # CHAIN length and width of Decane
                XVEC=$(echo $LENGTH  | awk '{printf "%8.5f\n", $1/4}' )
                NBASE=3
        else 
            NBASE=0
        fi
        WIDTH=$(echo 3.45 | awk '{printf "%8.5f\n", $1}')
        NATOMS=$(echo $NMOLS $NBASE | awk '{printf "%d\n", $1*$2}')


        printf "# Generate an array of $NMOLS = $1 x $2 x $3 $4 molecules and $NATOMS particles,\n" >> $OUTFILE
        printf '# aligned along x-axis, which (more or less) uniformly fills the simulation box:\n\n' >> $OUTFILE

        printf "$4 = new $4\t[$3].move(0, 0, $WIDTH)\n" >> $OUTFILE
        printf "\t\t\t\t\t[$2].move(0,  $WIDTH, 0)\n" >> $OUTFILE
        printf "\t\t\t\t\t[$1].move($XVEC, 0, 0)\n\n" >> $OUTFILE
}
# if run moltemplate
    MOLTEMPLAE=true
    OVITO=true

# CHAIN length and width of Decane
    LENGTH=12.53322
    WIDTH=$(echo $LENGTH | awk '{printf "%8.5f\n", $1/3}')

# boundary limitations: distance (tolerenace) between chains
    XLO=-1.075; YLO=-1.075; ZLO=-1.075

# numbers of decanes in each directions, it'll be orieanted in x-directions
    NX=1
    NY=10
    NZ=5
    MOLECULES=Decane

# WRITE_BOX decane spce_oplsaa $NX $NY $NZ
WRITE_MOL $NX $NY $NZ $MOLECULES
# numbers of waters in each directions, it'll be orieanted in x-directions
    NXW=8
    NY=10
    NZ=5
    MOLECULES=Water

# CHAIN length and width of Decane
    LENGTH=12.53322
    WRITE_MOL $NXW $NY $NZ $MOLECULES
    WRITE_BOX $NX $NXW $NY $NZ decane spce_oplsaa

printf '# Move the decane molecules slightly to reduce overlap with the water\n'  >> $OUTFILE
OFFSET=$(echo $NXW $LENGTH $XLO | awk '{printf "%8.5f", ($1*$2/4)}')

printf "Decane[*][*][*].move( $OFFSET, 0,0)\n"  >> $OUTFILE
# printf "Decane[0][1][0].rot(60,1,0,0,15.3056,3.63793,0)"  >> $OUTFILE

# run moltemplate
    if $MOLTEMPLAE; then
        /home/saeed/.local/bin/moltemplate.sh -atomstyle "full"  system.lt
        # rempve hybrid, opls, lj/cut/tip4p/long 
        sed -r -i 's/\b(harmonic|opls)\b//g' system.in.settings 
        sed -r -i 's/\b(lj\/cut\/coul\/long)\b//g' system.in.settings 
        # run OVITO
        if $OVITO; then
            ~/Downloads/ovito-basic-3.6.0-x86_64/bin/ovito system.data
        fi
    fi

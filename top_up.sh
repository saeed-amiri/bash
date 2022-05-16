#! /bin/bash
# NUMBER: N
# DECANE: D
# WATER: W
# ATOM: ATM
# BOND: BD
# DIHEDRAL: DH
# TYPE: T

# DECANE
D_NATM=6400; D_TATM=5
D_NBD=6200; D_TBD=3
D_NAG=12000; D_TAG=4
D_NDH=16200; D_TDH=3

# WATER
W_NATM=3630; W_TATM=2
W_NBD=2420; W_TBD=1
W_NAG=1210; W_TAG=1
W_NDH=0; W_TDH=0

INTERFACE=interface.data
>$INTERFACE
{
    printf "LAMMPS data from $1 and $2\n" 
    printf "\n" 

    printf "$((D_NATM+W_NATM)) atoms\n" 
    printf "$((D_TATM+W_TATM)) atom types\n"    
    printf "$((D_NBD+W_NBD)) bonds\n"   
    printf "$((D_TBD+W_TBD)) bond types\n"  
    printf "$((D_NAG+W_NAG)) angles\n"  
    printf "$((D_TAG+W_TAG)) angle types\n" 
    printf "$((D_NDH+W_NDH)) dihedrals\n" 
    printf "$((D_TDH+W_TDH)) dihedral types\n" 
    printf "\n" 

    echo  "-0.5417365183322508 51.74961651839575 xlo xhi" 
    echo  "-0.7087165831341256 35.20871658313476 ylo yhi" 
    echo  "-0.7087165831341256 57.0952916972267 zlo zhi" 
    printf "\n" 

    printf "Masses\n"
    printf "\n"
    printf "1 15.9994\n"
    printf "2 1.008\n"
    printf "3 12.011\n"
    printf "4 12.011\n"
    printf "5 1.008\n"
    printf "6 15.999\n"
    printf "7 1.008\n"
    printf "\n"
    printf "Pair Coeffs # lj/cut/coul/long\n"
    printf "\n"
    printf "1 lj/cut/coul/long 0.1553 3.166\n"
    printf "2 lj/cut/coul/long 0 0\n"
    printf "3 lj/cut/coul/long 0.066 3.5\n"
    printf "4 lj/cut/coul/long 0.066 3.5\n"
    printf "5 lj/cut/coul/long 0.03 2.5\n"
    printf "\n"
    printf "Bond Coeffs # harmonic\n"
    printf "\n"
    printf "1 harmonic 600 1\n"
    printf "2 harmonic 268 1.526\n"
    printf "3 harmonic 340 1.09\n"
    printf "\n"
    printf "Angle Coeffs # harmonic\n"
    printf "\n"
    printf "1 75 109.47\n"
    printf "2 58.35 112.7\n"
    printf "3 33 107.8\n"
    printf "4 37.5 110.7\n"
    printf "\n"
    printf "Dihedral Coeffs # opls\n"
    printf "\n"
    printf "1 1.3 -0.05 0.2 0\n"
    printf "2 0 0 0.3 0\n"
    printf "3 0 0 0.3 0\n"
    printf "\n" 
} >> $INTERFACE

printf "Atoms #full\n" >> $INTERFACE
printf "\n" >> $INTERFACE
cat atoms.decane >> $INTERFACE
cat atoms.water | awk '{$1+=6400;$2+=200;$3+=5}1'  >> $INTERFACE
printf "\n" >> $INTERFACE

printf "Bonds\n" >> $INTERFACE
printf "\n" >> $INTERFACE
cat bonds.decane >> $INTERFACE
cat bonds.water | awk '{$1+=6200;$2+=3;$3+=6400;$4+=6400}1' >> $INTERFACE



#!/bin/bash
#SBATCH --job-name=prepro
#SBATCH -e reduce.e%j
#SBATCH -o reduce.o%j
#SBATCH --time=01:30:00
#SBATCH -A egi@cpu
##SBATCH --partition=prepost
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --exclusive
#SBATCH --hint=nomultithread
#SBATCH --qos=qos_cpu-dev

. ./param01.bash

cd $wdir


i="44"
j="44"

t="39"
j="39"
i="39"
k="1"
for pair in "39 39" "44 44" "81 66" "56 30"; 
do
    i=${pair% *}
    j=${pair#* }

    cat > corr.cfg <<EOF
SSH $i $j $k $t 1
EOF

$sesam -mode corr -inxbas RED_1_ENS${ens_size}.cpak.bas -outvar RED1ENS-$i-$j-corr#.nc -incfg corr.cfg

$sesam -mode corr -inxbas RED_2_ENS${ens_size}.cpak.bas -outvar RED2ENScorr#.nc -incfg corr.cfg
$sesam -mode oper -invar RED2ENScorr#.nc -invarref RED2ENScorr#.nc -outvar RED2ENScorr2#.nc -typeoper x
$sesam -mode oper -invar RED2ENScorr2#.nc -invarref RED2ENScorr2#.nc -outvar RED2ENScorr4#.nc -typeoper x
$sesam -mode oper -invar RED2ENScorr4#.nc -invarref RED2ENScorr2#.nc -outvar RED2ENScorr6#.nc -typeoper x
$sesam -mode oper -invar RED2ENScorr6#.nc -invarref RED2ENScorr#.nc -outvar AUGENS-$i-$j-corr6#.nc -typeoper x

done

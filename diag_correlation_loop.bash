#!/bin/bash
#SBATCH --job-name=prepro
#SBATCH -e reduce.e%j
#SBATCH -o reduce.o%j
#SBATCH --time=02:00:00
#SBATCH -A egi@cpu
##SBATCH --partition=prepost
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --exclusive
#SBATCH --hint=nomultithread
#SBATCH --qos=qos_cpu-dev

. ./param.bash

cd $wdir


i="44"
j="44"

t="39"
# j="39"
# i="39"

for idepth in $(seq 1 63); do

    cat > corr.cfg <<EOF
SAL $i $j $idepth $t 1
EOF

    $sesam -mode corr -inxbas RED_1_ENS${ens_size}.cpak.bas -outvar RED1ENScorr_SAL${i}-${j}_${idepth}#.nc -incfg corr.cfg
done

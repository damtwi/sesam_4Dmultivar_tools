#!/bin/bash
#SBATCH --job-name=checkscore
#SBATCH -e logs/checkscore.e%j
#SBATCH -o logs/checkscore.o%j
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --time=02:00:00            # Temps d’exécution maximum demande (HH:MM:SS)
#SBATCH --exclusive
#SBATCH -A egi@cpu
#SBATCH --hint=nomultithread
##SBATCH --qos=qos_cpu-dev
#SBATCH --qos=qos_cpu-dev


PARAM_TEMPLATE="param0-300.bash"
jobid=""
# for i in $(seq -w 1 1); do	# 
for i in 2 4 6 8 10; do
    date

    xt=$(printf "%02d" $((10#$i)))
    echo "#### member $xt ####"
    echo "PWD: $(pwd)"
    
    # Copier param.bash en param{xt}.bash
    
    PARAM_FILE="param${xt}.bash"
    
    cp "$PARAM_TEMPLATE" "$PARAM_FILE"
    # Modifier memxt et wdir à l'intérieur du param{xt}.bash
    sed -i "s/^memxt=.*/memxt=\"$xt\"/" "$PARAM_FILE"
    
    # On suppose que le dossier parent $SCRATCH/SNOOPI/ExpEns existe
    WDIR_SUB="$SCRATCH/SNOOPI/ExpEns/$xt"
    sed -i "s|^wdir=.*|wdir=\"$WDIR_SUB\"|" "$PARAM_FILE"   
    . ./${PARAM_FILE}
    cd $wdir
    $sesam -mode intf -invar xt#.nc -outvar xt_prior.cpak
    smpensdir="${expt}SMPENS${upd_size}"
    mkdir ${smpensdir}.cpak.bas
    $sesam -mode intf -inxbas ${smpensdir}.nc.bas -outxbas ${smpensdir}.cpak.bas
    cd $sdir
done 
